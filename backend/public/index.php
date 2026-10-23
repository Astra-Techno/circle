<?php

declare(strict_types=1);

require_once __DIR__ . '/../vendor/autoload.php';

use Circle\Core\Env;
use Circle\Core\Request;
use Circle\Core\Response;
use Circle\Core\Router;
use Circle\Controllers\AuthController;
use Circle\Controllers\GroupController;
use Circle\Controllers\MemberController;
use Circle\Controllers\MemoryController;
use Circle\Middleware\AuthMiddleware;
use Circle\Middleware\CorsMiddleware;
use Circle\Middleware\RateLimitMiddleware;

// Load environment
Env::load(__DIR__ . '/..');

// Error handling
set_exception_handler(function (\Throwable $e) {
    error_log('[CIRCLE] ' . $e->getMessage() . ' in ' . $e->getFile() . ':' . $e->getLine());
    if (Env::bool('APP_DEBUG')) {
        Response::error('server_error', $e->getMessage(), 500);
    }
    Response::serverError();
});

$router = new Router();

// Register middleware
$router->registerMiddleware('cors', CorsMiddleware::handle(...));
$router->registerMiddleware('auth', AuthMiddleware::handle(...));
$router->registerMiddleware('rate', RateLimitMiddleware::handle(...));
$router->registerMiddleware('rate:auth', RateLimitMiddleware::authHandle(...));

// Health check
$router->get('/api/v1/health', function () {
    Response::ok(['status' => 'healthy', 'time' => date('c')]);
}, ['cors']);

// ── Auth (public, rate-limited) ──────────────────────────────
$router->group('/api/v1/auth', ['cors', 'rate:auth'], function (Router $r) {
    $r->post('/register', AuthController::register(...));
    $r->post('/login', AuthController::login(...));
    $r->post('/refresh', AuthController::refresh(...));
});

// ── Auth (protected) ─────────────────────────────────────────
$router->group('/api/v1/auth', ['cors', 'auth'], function (Router $r) {
    $r->post('/logout', AuthController::logout(...));
});

// ── Invite preview (public) ──────────────────────────────────
$router->get('/api/v1/invites/{token}', MemberController::previewInvite(...), ['cors']);

// ── Protected API ────────────────────────────────────────────
$router->group('/api/v1', ['cors', 'auth', 'rate'], function (Router $r) {

    // Profile
    $r->get('/me', AuthController::me(...));
    $r->patch('/me', AuthController::updateMe(...));

    // Groups
    $r->get('/groups', GroupController::index(...));
    $r->post('/groups', GroupController::create(...));
    $r->get('/groups/{id}', GroupController::show(...));
    $r->patch('/groups/{id}', GroupController::update(...));
    $r->get('/groups/{id}/subgroups', GroupController::subgroups(...));
    $r->post('/groups/{id}/leave', GroupController::leave(...));
    $r->post('/groups/{id}/transfer-ownership', GroupController::transferOwnership(...));

    // Members
    $r->get('/groups/{id}/members', MemberController::index(...));
    $r->patch('/groups/{id}/members/{userId}', MemberController::updateRole(...));
    $r->delete('/groups/{id}/members/{userId}', MemberController::remove(...));

    // Invite links
    $r->post('/groups/{id}/invite-links', MemberController::createInviteLink(...));
    $r->post('/invites/{token}/join', MemberController::joinViaInvite(...));

    // Join requests
    $r->get('/groups/{id}/join-requests', MemberController::joinRequests(...));
    $r->post('/groups/{id}/join-requests/{rid}/approve', MemberController::approveRequest(...));
    $r->post('/groups/{id}/join-requests/{rid}/decline', MemberController::declineRequest(...));

    // Memories
    $r->get('/memories', MemoryController::index(...));
    $r->post('/groups/{id}/memories', function (Request $req) {
        // Inject group_id from URL param into request body for the controller
        $groupId = $req->param('id');
        $_POST['group_id'] = $groupId;
        MemoryController::create(new Request());
    });
    $r->get('/memories/{id}', MemoryController::show(...));
    $r->patch('/memories/{id}', MemoryController::update(...));
    $r->delete('/memories/{id}', MemoryController::delete(...));

    // Comments & Reactions
    $r->post('/memories/{id}/comments', MemoryController::addComment(...));
    $r->post('/memories/{id}/reactions', MemoryController::react(...));
    $r->post('/memories/{id}/save', MemoryController::save(...));
});

// Dispatch
$request = new Request();
$router->dispatch($request);
