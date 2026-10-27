package com.circlecommunity.push;

import android.app.Activity;
import android.app.Application;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.util.Base64;
import android.security.keystore.KeyGenParameterSpec;
import android.security.keystore.KeyProperties;
import java.security.KeyStore;
import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;
import java.nio.charset.StandardCharsets;
import java.util.HashMap;
import java.util.Iterator;
import java.util.Map;
import java.util.UUID;
import org.json.JSONObject;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.PluginRegistry;

/** Registered in both main and Firebase headless engines. All channel calls run
 * on Android's main thread. Static state serializes isolates in this app process.
 * Only scope digests and expiry/dedup metadata persist here, never credentials. */
public final class CirclePushPlugin implements FlutterPlugin, ActivityAware,
        MethodChannel.MethodCallHandler, EventChannel.StreamHandler,
        PluginRegistry.NewIntentListener {
    private static final String CHANNEL = "circle_updates_v1";
    private static final String EXTRA = "circle.push.envelope";
    private static final String PREFS = "circle.push.native.v1";
    private static String mutexOwner;
    private static EventChannel.EventSink taps;
    private EventChannel.EventSink ownedSink;
    private Context context;
    private ActivityPluginBinding activityBinding;
    private MethodChannel methods;
    private EventChannel events;

    @Override public void onAttachedToEngine(FlutterPluginBinding binding) {
        context = binding.getApplicationContext();
        methods = new MethodChannel(binding.getBinaryMessenger(), "circle/push_native");
        events = new EventChannel(binding.getBinaryMessenger(), "circle/push_taps");
        methods.setMethodCallHandler(this);
        events.setStreamHandler(this);
    }
    @Override public void onDetachedFromEngine(FlutterPluginBinding binding) {
        if (taps == ownedSink) taps = null;
        ownedSink = null;
        methods.setMethodCallHandler(null);
        events.setStreamHandler(null);
    }
    private SharedPreferences prefs() { return context.getSharedPreferences(PREFS, Context.MODE_PRIVATE); }
    private NotificationManager manager() { return (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE); }
    private static boolean digest(String value) { return value != null && value.matches("[a-f0-9]{64}"); }
    private static String text(MethodCall call, String key) {
        Object value = call.argument(key); return value instanceof String ? (String) value : "";
    }
    @Override public void onMethodCall(MethodCall call, MethodChannel.Result result) {
        try {
            switch (call.method) {
                case "lock":
                    if (mutexOwner != null) { result.success(null); return; }
                    mutexOwner = UUID.randomUUID().toString(); result.success(mutexOwner); return;
                case "unlock":
                    if (text(call, "lease").equals(mutexOwner)) mutexOwner = null;
                    result.success(null); return;
                case "bind": {
                    String scope = text(call, "scope");
                    if (!scope.isEmpty() && !digest(scope)) throw new IllegalArgumentException();
                    String old = prefs().getString("scope", "");
                    // Cancel prior-session lock-screen entries on every invalidation.
                    if (!old.equals(scope) || scope.isEmpty()) manager().cancelAll();
                    // Transport stops must not erase unacknowledged opens.
                    // Dart rejects/acks foreign scopes; readTaps prunes expiry.
                    if (!prefs().edit().putString("scope", scope).commit()) throw new IllegalStateException();
                    result.success(null); return;
                }
                case "ack": {
                    JSONObject queue = readTaps(); queue.remove(text(call, "id"));
                    writeTaps(queue); result.success(null); return;
                }
                case "show": result.success(show(call)); return;
                case "initial": {
                    JSONObject queue = readTaps();
                    Iterator<String> ids = queue.keys();
                    result.success(ids.hasNext() ? tapMessage(queue, ids.next()) : null); return;
                }
                default: result.notImplemented();
            }
        } catch (Exception error) {
            // No payload, device ids, private text or credentials in errors/logs.
            result.error("unavailable", "Notification operation unavailable.", null);
        }
    }
    private boolean show(MethodCall call) throws Exception {
        String scope = text(call, "scope"), event = text(call, "event"), payload = text(call, "payload");
        Object rawExpiry = call.argument("expires");
        if (!digest(scope) || !digest(event) || payload.length() > 4096 || !(rawExpiry instanceof Number)) return false;
        long expiry = ((Number) rawExpiry).longValue(), now = System.currentTimeMillis() / 1000;
        if (expiry <= now || expiry > now + 86700 || !scope.equals(prefs().getString("scope", ""))) return false;
        if (!manager().areNotificationsEnabled()) return false;
        if (Build.VERSION.SDK_INT >= 26) {
            NotificationChannel channel = new NotificationChannel(CHANNEL, "Circle updates", NotificationManager.IMPORTANCE_DEFAULT);
            channel.setDescription("Memories, comments and replies you choose to receive");
            channel.setSound(null, null);
            channel.setShowBadge(true);
            manager().createNotificationChannel(channel);
            if (manager().getNotificationChannel(CHANNEL).getImportance() == NotificationManager.IMPORTANCE_NONE) return false;
        }
        JSONObject history = new JSONObject(prefs().getString("history", "{}"));
        Iterator<String> keys = history.keys();
        while (keys.hasNext()) { String key = keys.next(); if (history.getLong(key) <= now) keys.remove(); }
        String tag = "circle:" + scope + ":" + event;
        if (history.has(tag)) return true;
        if (history.length() >= 512) return false;
        // Explicit immutable intent; payload contains only validated references.
        Intent intent = context.getPackageManager().getLaunchIntentForPackage(context.getPackageName());
        if (intent == null) return false;
        intent.setAction("com.circlecommunity.mobile.PUSH_OPEN");
        intent.setData(Uri.parse("circle-push-internal:" + scope + event));
        intent.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP | Intent.FLAG_ACTIVITY_CLEAR_TOP);
        intent.putExtra(EXTRA, payload);
        PendingIntent tap = PendingIntent.getActivity(context, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        Notification.Builder builder = Build.VERSION.SDK_INT >= 26
                ? new Notification.Builder(context, CHANNEL) : new Notification.Builder(context);
        int icon = R.drawable.ic_circle_notification;
        builder.setSmallIcon(icon).setContentTitle("CIRCLE")
                .setContentText("There’s an update in your circle.")
                .setVisibility(Notification.VISIBILITY_PRIVATE).setCategory(Notification.CATEGORY_SOCIAL)
                .setContentIntent(tap).setAutoCancel(true).setOnlyAlertOnce(true);
        if (Build.VERSION.SDK_INT >= 26) builder.setTimeoutAfter((expiry - now) * 1000);
        // Show before history: process death may replay the same tag, replacing
        // the existing notification. Do not mark delivered before OS handoff.
        manager().notify(tag, 0, builder.build());
        history.put(tag, expiry);
        if (!prefs().edit().putString("history", history.toString()).commit()) return false;
        return true;
    }
    private SecretKey tapKey() throws Exception {
        KeyStore store = KeyStore.getInstance("AndroidKeyStore"); store.load(null);
        String alias = "circle.push.tap.v1";
        if (store.containsAlias(alias)) return (SecretKey) store.getKey(alias, null);
        KeyGenerator generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore");
        generator.init(new KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_ENCRYPT | KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).build());
        return generator.generateKey();
    }
    private JSONObject readTaps() throws Exception {
        String raw = prefs().getString("taps", null);
        if (raw == null) return new JSONObject();
        String[] parts = raw.split(":", -1);
        if (parts.length != 2) throw new IllegalStateException();
        Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
        cipher.init(Cipher.DECRYPT_MODE, tapKey(), new GCMParameterSpec(128, Base64.decode(parts[0], Base64.NO_WRAP)));
        JSONObject queue = new JSONObject(new String(cipher.doFinal(Base64.decode(parts[1], Base64.NO_WRAP)), StandardCharsets.UTF_8));
        Iterator<String> ids = queue.keys();
        long now = System.currentTimeMillis() / 1000;
        while (ids.hasNext()) {
            String id = ids.next();
            JSONObject envelope = new JSONObject(queue.getString(id));
            if (Long.parseLong(envelope.getString("expires_at")) <= now) ids.remove();
        }
        return queue;
    }
    private void writeTaps(JSONObject queue) throws Exception {
        Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding"); cipher.init(Cipher.ENCRYPT_MODE, tapKey());
        String raw = Base64.encodeToString(cipher.getIV(), Base64.NO_WRAP) + ":" +
                Base64.encodeToString(cipher.doFinal(queue.toString().getBytes(StandardCharsets.UTF_8)), Base64.NO_WRAP);
        if (!prefs().edit().putString("taps", raw).commit()) throw new IllegalStateException();
    }
    private String tapMessage(JSONObject queue, String id) throws Exception {
        return new JSONObject().put("circle_native_tap", new JSONObject().put("id", id)
                .put("data", new JSONObject(queue.getString(id)))).toString();
    }
    private boolean accept(Intent intent) {
        if (intent == null) return false;
        String payload = intent.getStringExtra(EXTRA);
        if (payload == null || payload.length() > 4096) return false;
        try {
            JSONObject data = new JSONObject(payload);
            long expiry = Long.parseLong(data.getString("expires_at")), now = System.currentTimeMillis() / 1000;
            if (expiry <= now || expiry > now + 86700) return false;
            JSONObject queue = readTaps();
            if (queue.length() >= 8) return false;
            String id = UUID.randomUUID().toString(); queue.put(id, payload);
            writeTaps(queue); // Durable encrypted handoff before consuming Intent.
            intent.removeExtra(EXTRA);
            if (taps != null) taps.success(tapMessage(queue, id));
            return true;
        } catch (Exception error) { return false; }
    }
    @Override public boolean onNewIntent(Intent intent) { return accept(intent); }
    @Override public void onAttachedToActivity(ActivityPluginBinding binding) {
        activityBinding = binding; binding.addOnNewIntentListener(this);
        accept(binding.getActivity().getIntent());
    }
    @Override public void onDetachedFromActivity() {
        if (activityBinding != null) activityBinding.removeOnNewIntentListener(this);
        activityBinding = null;
    }
    @Override public void onDetachedFromActivityForConfigChanges() { onDetachedFromActivity(); }
    @Override public void onReattachedToActivityForConfigChanges(ActivityPluginBinding binding) { onAttachedToActivity(binding); }
    @Override public void onListen(Object args, EventChannel.EventSink sink) {
        ownedSink = sink; taps = sink;
        try {
            JSONObject queue = readTaps(); Iterator<String> ids = queue.keys();
            while (ids.hasNext()) sink.success(tapMessage(queue, ids.next()));
        } catch (Exception error) { sink.error("unavailable", "Notification taps unavailable.", null); }
    }
    @Override public void onCancel(Object args) {
        if (taps == ownedSink) taps = null;
        ownedSink = null;
    }
}
