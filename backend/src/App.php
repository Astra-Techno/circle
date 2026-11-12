<?php

declare(strict_types=1);

namespace Circle;

use Circle\Controllers\AuthController;
use Circle\Controllers\SessionController;
use Circle\Controllers\DeviceController;
use Circle\Controllers\NotificationPreferenceController;
use Circle\Controllers\ProfilePhotoController;
use Circle\Controllers\GroupPhotoController;
use Circle\Controllers\ModerationController;
use Circle\Controllers\BlockController;
use Circle\Controllers\ChatController;
use Circle\Controllers\EventController;
use Circle\Controllers\GroupController;
use Circle\Controllers\GroupInvitationController;
use Circle\Controllers\MediaController;
use Circle\Controllers\MemberController;
use Circle\Controllers\MemoryController;
use Circle\Controllers\CapsuleController;
use Circle\Controllers\AlbumController;
use Circle\Controllers\SearchController;
use Circle\Controllers\ActivityController;
use Circle\Core\ConfigException;
use Circle\Core\Database;
use Circle\Core\JWT;
use Circle\Core\Log;
use Circle\Core\Request;
use Circle\Core\Response;
use Circle\Core\ResponseSent;
use Circle\Core\Router;
use Circle\Middleware\AuthMiddleware;
use Circle\Middleware\CorsMiddleware;
use Circle\Middleware\RateLimitMiddleware;

/**
 * Builds the routes and handles one request. public/index.php and the tests
 * both go through handle(), so tests exercise the real HTTP layer in-process.
 */
final class App
{
    private static ?Router $router = null;

    public static function router(): Router
    {
        if (self::$router !== null) {
            return self::$router;
        }

        $router = new Router();

        $router->registerMiddleware('auth', AuthMiddleware::handle(...));
        $router->registerMiddleware('rate', RateLimitMiddleware::handle(...));
        $router->registerMiddleware('rate:profile_photo', RateLimitMiddleware::profilePhotoHandle(...));
        $router->registerMiddleware('rate:media', RateLimitMiddleware::mediaReadHandle(...));
        $router->registerMiddleware('rate:auth', RateLimitMiddleware::authHandle(...));

        $router->get('/api/v1/health', static function (): void {
            Response::ok(['status' => 'healthy', 'time' => gmdate('c')]);
        });

        // ── Push test (deploy-key protected, remove after testing) ──
        $router->get('/api/v1/push-test', static function (Request $request): void {
            $key = $request->query('key');
            if ($key === '' || !hash_equals(\Circle\Core\Env::get('DEPLOY_KEY'), $key)) {
                Response::unauthorized('Invalid key.');
            }

            try {
                $sender = new \Circle\Core\FcmSender();
                $fcmReady = $sender->isReady();
                $db = Database::connection();

                $tokens = $db->query(
                    'SELECT dt.fcm_token, dt.platform, dt.user_id, u.display_name, dt.created_at
                     FROM device_tokens dt JOIN users u ON u.id = dt.user_id
                     ORDER BY dt.created_at DESC LIMIT 20'
                )->fetchAll(\PDO::FETCH_ASSOC);

                $results = [];
                $now = time();
                foreach ($tokens as $row) {
                    $data = [
                        'type'       => 'test',
                        'title'      => 'Circle Push Test',
                        'body'       => 'Push notifications are working!',
                        'event'      => 'push_test',
                        'scope'      => 'system',
                        'expires_at' => (string) ($now + 300),
                        'sent_at'    => (string) $now,
                    ];
                    $result = $sender->send($row['fcm_token'], $data);
                    $results[] = [
                        'user'     => $row['display_name'],
                        'platform' => $row['platform'],
                        'token'    => substr($row['fcm_token'], 0, 20) . '...',
                        'status'   => $result->status,
                    ];
                }

                Response::ok([
                    'fcm_ready'   => $fcmReady,
                    'devices'     => count($tokens),
                    'results'     => $results,
                ]);
            } catch (\Throwable $e) {
                Response::json([
                    'success' => false,
                    'debug'   => $e->getMessage(),
                    'file'    => basename($e->getFile()) . ':' . $e->getLine(),
                    'trace'   => array_slice(array_map(fn($f) => basename($f['file'] ?? '?') . ':' . ($f['line'] ?? '?') . ' ' . ($f['class'] ?? '') . ($f['type'] ?? '') . $f['function'], $e->getTrace()), 0, 8),
                ], 500);
            }
        });

        // ── Auth (public, rate-limited) ──────────────────────────
        $router->group('/api/v1/auth', ['rate:auth'], static function (Router $r): void {
            $r->post('/register', AuthController::register(...));
            $r->post('/login', AuthController::login(...));
            $r->post('/refresh', AuthController::refresh(...));
        });

        // ── Auth (protected) ─────────────────────────────────────
        $router->group('/api/v1/auth', ['rate', 'auth'], static function (Router $r): void {
            $r->post('/logout', AuthController::logout(...));
            $r->post('/change-password', AuthController::changePassword(...));
        });

        // ── Invite preview (public, rate-limited) ────────────────
        $router->get('/api/v1/invites/{token}', MemberController::previewInvite(...), ['rate']);

        // Authenticated private profile reads have a separate bounded budget.
        $router->get('/api/v1/groups/{id}/photos/{kind}', GroupPhotoController::show(...), ['auth', 'rate:profile_photo']);
        $router->get('/api/v1/me/photos/{kind}', ProfilePhotoController::show(...), ['auth', 'rate:profile_photo']);
        $router->get('/api/v1/profiles/{userId}/photos/{kind}', ProfilePhotoController::show(...), ['auth', 'rate:profile_photo']);
        // Media bytes: the HMAC-signed link is the credential (no bearer).
        $router->get('/api/v1/media/files/{mediaId}/{size}', MediaController::file(...), ['rate:media']);

        // Read-only media has its own bounded quota; private access is unchanged.
        $router->get('/api/v1/media/{mediaId}', MediaController::link(...), ['auth', 'rate:media']);
        $router->get('/api/v1/chats/{id}/media/{mediaId}', \Circle\Controllers\FeatureMediaController::chatPhoto(...), ['auth', 'rate:media']);
        $router->get('/api/v1/events/{eventId}/cover', \Circle\Controllers\FeatureMediaController::cover(...), ['auth', 'rate:media']);

        // ── Protected API ────────────────────────────────────────
        $router->group('/api/v1', ['rate', 'auth'], static function (Router $r): void {
            $r->get('/me/chat-privacy', ChatController::privacy(...));
            $r->patch('/me/chat-privacy', ChatController::privacy(...));
            $r->get('/groups/{id}/chat', ChatController::group(...));
            $r->get('/chats', ChatController::inbox(...));
            $r->get('/chats/contacts', ChatController::contacts(...));
            $r->put('/chats/direct/{userId}', ChatController::direct(...));
            $r->get('/chats/{id}', ChatController::show(...));
            $r->patch('/chats/{id}/state', ChatController::state(...));
            $r->post('/chats/{id}/reports', ChatController::report(...));
            $r->post('/chats/{id}/request', ChatController::respond(...));
            $r->post('/chats/{id}/messages', ChatController::send(...));
            $r->get('/chats/{id}/messages/{messageId}', ChatController::pushMessage(...));
            $r->patch('/chats/{id}/messages/{messageId}', ChatController::changeMessage(...));
            $r->put('/chats/{id}/messages/{messageId}/reaction', ChatController::react(...));
            $r->put('/chats/{id}/uploads/{mediaId}', \Circle\Controllers\FeatureMediaController::uploadChat(...));
            $r->put('/events/{eventId}/cover', \Circle\Controllers\FeatureMediaController::putCover(...));
            $r->delete('/events/{eventId}/cover', \Circle\Controllers\FeatureMediaController::deleteCover(...));
            $r->get('/polls', \Circle\Controllers\PollController::index(...));
            $r->post('/groups/{id}/polls', \Circle\Controllers\PollController::create(...));
            $r->get('/polls/{pollId}', \Circle\Controllers\PollController::show(...));
            $r->put('/polls/{pollId}/votes', \Circle\Controllers\PollController::vote(...));
            $r->post('/polls/{pollId}/options', \Circle\Controllers\PollController::addOption(...));
            $r->post('/polls/{pollId}/close', \Circle\Controllers\PollController::close(...));
            $r->get('/polls/{pollId}/voters', \Circle\Controllers\PollController::voters(...));
            $r->get('/events', EventController::index(...));
            $r->post('/groups/{id}/events', EventController::create(...));
            $r->get('/events/{eventId}', EventController::show(...));
            $r->patch('/events/{eventId}', EventController::update(...));
            $r->put('/events/{eventId}/rsvp', EventController::rsvp(...));
            $r->get('/events/{eventId}/attendees', EventController::attendees(...));
            $r->get('/me/blocks', BlockController::index(...));
            $r->get('/me/blocks/{userId}', BlockController::show(...));
            $r->put('/me/blocks/{userId}', BlockController::put(...));
            $r->delete('/me/blocks/{userId}', BlockController::delete(...));
            // Profile
            $r->get('/me/sessions', SessionController::index(...));
            $r->delete('/me/sessions/{sessionId}', SessionController::revoke(...));
            $r->patch('/me/session', SessionController::update(...));
            $r->get('/me', AuthController::me(...));
            $r->patch('/me', AuthController::updateMe(...));
            $r->put('/me/photos/{kind}', ProfilePhotoController::put(...));
            $r->delete('/me/photos/{kind}', ProfilePhotoController::delete(...));

            $r->get('/me/notification-preferences', NotificationPreferenceController::show(...));
            $r->patch('/me/notification-preferences', NotificationPreferenceController::update(...));

            // Groups
            $r->post('/groups/{id}/reports', ModerationController::create(...));
            $r->get('/groups/{id}/reports', ModerationController::index(...));
            $r->post('/groups/{id}/reports/{reportTargetId}/actions', ModerationController::action(...));
            $r->get('/groups', GroupController::index(...));
            $r->post('/groups', GroupController::create(...));
            $r->get('/groups/{id}', GroupController::show(...));
            $r->put('/groups/{id}/photos/{kind}', GroupPhotoController::put(...));
            $r->delete('/groups/{id}/photos/{kind}', GroupPhotoController::delete(...));
            $r->patch('/groups/{id}', GroupController::update(...));
            $r->get('/groups/{id}/subgroups', GroupController::subgroups(...));
            $r->post('/groups/{id}/leave', GroupController::leave(...));
            $r->post('/groups/{id}/transfer-ownership', GroupController::transferOwnership(...));

            $r->post('/groups/{id}/contact-invitations', GroupInvitationController::create(...));
            $r->get('/me/group-invitations', GroupInvitationController::index(...));
            $r->get('/group-invitations/{invitationId}', GroupInvitationController::show(...));
            $r->post('/group-invitations/{invitationId}/accept', GroupInvitationController::accept(...));
            $r->post('/group-invitations/{invitationId}/decline', GroupInvitationController::decline(...));

            // Members
            $r->get('/groups/{id}/members', MemberController::index(...));
            $r->patch('/groups/{id}/members/{userId}', MemberController::updateRole(...));
            $r->delete('/groups/{id}/members/{userId}', MemberController::remove(...));
            $r->post('/groups/{id}/members/{userId}/unban', MemberController::unban(...));

            // Invite links
            $r->get('/groups/{id}/invite-links', MemberController::listInviteLinks(...));
            $r->post('/groups/{id}/invite-links', MemberController::createInviteLink(...));
            $r->post('/groups/{id}/invite-links/reset', MemberController::resetInviteLinks(...));
            $r->delete('/groups/{id}/invite-links/{linkId}', MemberController::revokeInviteLink(...));
            $r->post('/invites/{token}/join', MemberController::joinViaInvite(...));

            // Join requests
            $r->get('/groups/{id}/join-requests', MemberController::joinRequests(...));
            $r->post('/groups/{id}/join-requests/{rid}/approve', MemberController::approveRequest(...));
            $r->post('/groups/{id}/join-requests/{rid}/decline', MemberController::declineRequest(...));

            // Memories
            $r->get('/memories', MemoryController::index(...));
            $r->post('/groups/{id}/memories', MemoryController::create(...));
            $r->get('/memories/{id}', MemoryController::show(...));
            $r->patch('/memories/{id}', MemoryController::update(...));
            $r->delete('/memories/{id}', MemoryController::delete(...));

            // Comments, reactions, saves
            $r->post('/memories/{id}/comments', MemoryController::addComment(...));
            $r->delete('/memories/{id}/comments/{commentId}', MemoryController::deleteComment(...));
            $r->post('/memories/{id}/comments/{commentId}/restore', MemoryController::restoreComment(...));
            $r->post('/memories/{id}/reactions', MemoryController::react(...));
            $r->post('/memories/{id}/save', MemoryController::save(...));

            // Private media (ADR 0007)
            $r->post('/groups/{id}/media/uploads', MediaController::createUpload(...));
            $r->put('/media/uploads/{uploadId}/content', MediaController::uploadContent(...));
            $r->delete('/media/{mediaId}', MediaController::discard(...));

            // Capsules
            $r->get('/groups/{id}/capsules', CapsuleController::index(...));
            $r->post('/groups/{id}/capsules', CapsuleController::create(...));
            $r->get('/capsules/{capsuleId}', CapsuleController::show(...));
            $r->post('/capsules/{capsuleId}/entries', CapsuleController::addEntry(...));
            $r->get('/capsules/{capsuleId}/entries', CapsuleController::entries(...));
            $r->post('/capsules/{capsuleId}/seal', CapsuleController::seal(...));
            $r->delete('/capsules/{capsuleId}', CapsuleController::delete(...));

            // Albums
            $r->get('/groups/{id}/albums', AlbumController::index(...));
            $r->post('/groups/{id}/albums', AlbumController::create(...));
            $r->get('/albums/{albumId}', AlbumController::show(...));
            $r->patch('/albums/{albumId}', AlbumController::update(...));
            $r->delete('/albums/{albumId}', AlbumController::delete(...));
            $r->post('/albums/{albumId}/photos', AlbumController::addPhoto(...));
            $r->patch('/albums/{albumId}/photos/{photoId}', AlbumController::updatePhoto(...));
            $r->delete('/albums/{albumId}/photos/{photoId}', AlbumController::removePhoto(...));

            // Search
            $r->get('/search', SearchController::search(...));

            // Activity / notification inbox
            $r->get('/me/activity', ActivityController::index(...));
            $r->post('/me/activity/read', ActivityController::markRead(...));

            // Device tokens (FCM push notifications)
            $r->post('/devices/register', DeviceController::register(...));
            $r->post('/devices/unregister', DeviceController::unregister(...));
        });

        return self::$router = $router;
    }

    /**
     * Handles one request. Unexpected errors become generic responses; details
     * go to the (redacted) error log only, never to the client.
     */
    public static function handle(Request $request): void
    {
        Response::reset();

        // Flush pending push notifications after every response, removing
        // the need for a cron job.  The shutdown function runs after exit,
        // so the client already has the HTTP response.
        Notifications\NotificationDispatcher::scheduleFlush();

        try {
            // Refuse to serve anything with an unsafe signing secret.
            JWT::secret();

            CorsMiddleware::apply($request);
            if ($request->method === 'OPTIONS') {
                Response::noContent();
            }

            self::router()->dispatch($request);
        } catch (ResponseSent $sent) {
            throw $sent;
        } catch (ConfigException $e) {
            Log::exception('configuration', $e);
            Response::serverError('The server is not configured correctly.');
        } catch (\PDOException $e) {
            Database::rollback();
            Log::exception('database', $e);
            if (Database::isDuplicateKey($e)) {
                Response::error('conflict', 'This conflicts with existing data. Refresh and try again.', 409);
            }
            Response::serverError();
        } catch (\Throwable $e) {
            Database::rollback();
            Log::exception('unhandled', $e);
            Response::serverError();
        }
    }
}
