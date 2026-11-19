# Background Notifications & Keep-Alive Architecture

## Prior Art & Credit
The background keep-alive technique used here is based on [Exteria](https://github.com/sqmrak/exteria.git) by sqmrak. Exteria demonstrated that playing an in-memory silent PCM audio loop with `AVAudioSessionCategoryPlayback` and `AVAudioSessionCategoryOptionMixWithOthers` keeps an iOS 6 process alive indefinitely in the background without user-audible sound or interruption to other media apps.

## Problem Statement
Standard Telegram push notifications rely on Apple Push Notification service (APNs). On iOS 6.0–12.5.7 devices, APNs is unviable for sideloaded or custom builds without Apple Developer team certificates, and Apple APNs TLS protocols on iOS 6 suffer from outdated cipher suites. When an app is suspended, iOS freezes TCP sockets, causing TDLib to disconnect within 10–30 s.

## Architecture

### 1. Keep-Alive (`TGBackgroundKeeper`)
- Plays a 1 s 8 kHz mono 16-bit PCM silent WAV from memory via `AVAudioPlayer`.
- Session category: `AVAudioSessionCategoryPlayback`.
- Category option: `AVAudioSessionCategoryOptionMixWithOthers` (does not interrupt iPod music or video playback in other apps).
- Number of loops: `-1` (infinite).
- Power impact: `mediaserverd` consumes ~4.9 MB RSS and minimal CPU cycles (~0.1%) processing empty PCM frames.

### 2. Network & Event Pipeline
- With the process kept alive in the background, TDLib's receive thread (`tg.receive`) stays parked in `td_json_client_receive`.
- When a new message arrives over the open TCP socket:
  1. TDLib receives `updateNewMessage`.
  2. `TGClient` checks:
     - Message is incoming (`!is_outgoing`).
     - Chat is not muted (`[self isChatMuted:chatId]`).
     - Message date is within 15 s clock skew margin of `readyAt`.
  3. `TGClient` posts `TGInAppNotificationReceivedNotification`.
  4. `AppDelegate` checks `applicationState != UIApplicationStateActive`.
  5. Schedules a `UILocalNotification`:
     - `alertBody = "Sender: Message text"`.
     - `alertAction = "Open"`.
     - `soundName = UILocalNotificationDefaultSoundName`.
     - `userInfo = @{ @"chatId" : ... }`.

### 3. iOS 5/6 SpringBoard & BulletinBoard Integration
On iOS 5 and 6, apps installed in `/Applications/` (system/internal partitions) do not automatically generate BulletinBoard notification banners because SpringBoard treats them as internal system tools.
To enable notification banners and sounds:
1. `resources/Info.plist`:
   - `SBAppTags` contains `"SBInternalAppTag"`.
2. SpringBoard preferences (`/var/mobile/Library/Preferences/com.apple.springboard.plist`):
   - `SBShowInternalApps = true`.
3. BulletinBoard records (`/var/mobile/Library/BulletinBoard/SectionInfo.plist` and `SectionOrder.plist`):
   - Section ID `org.legacy.itg` registered with `alertType = 1` (banner), `showsInLockScreen = 1`, `showsInNotificationCenter = 1`.

### 4. Memory Footprint & Jetsam Defense
256 MB devices (iPod touch 4th gen, iPhone 3GS/4 — Vintage tier) have strict kernel Jetsam limits: ~40–45 MB dirty limit in background.
To ensure the app survives in background indefinitely:
- **Vintage tier cache ceilings**:
  - `TGPeerStore._photos`: 30 (down from 120).
  - `TGChatListStore._previewImages`: 20 (down from 80).
  - `TGChatViewLayout.layoutCache`: 80 (down from 500).
  - `TGChatViewLayout.senderAvatars`: 24 (down from 120).
- **Background purging**:
  - Upon `applicationDidEnterBackground:`, `TGRecursivePurgeVC` walks view controllers and calls `clearMemoryCaches`.
  - `TGMediaStore` clears image buffer caches.
  - `malloc_zone_pressure_relief(zone, 0)` returns unmapped pages to the kernel.
- **Memory warning handler**:
  - `AppDelegate.applicationDidReceiveMemoryWarning:` triggers `purgeMemoryCaches` to drop caches before Jetsam SIGKILL.

### 5. Verified Hardware Metrics (iPod touch 4, iOS 6.1.6)
- Launch (3 s): 36.4 MB Task / 30.0 MB Dirty (reduced from 59.9 MB Task / 45.7 MB Dirty).
- Foreground settled (9 s): 40.5 MB Task / 33.8 MB Dirty.
- Background idle (audio keep-alive active): 40.1 MB Task / 33.3 MB Dirty.
- Large heap blocks (>= 64 KB): 9.9 MB total.
