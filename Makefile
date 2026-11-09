# ==============================================================================
# LegacyTG - Makefile
# Clean, architecture-separated build pipeline for iOS (armv7 32-bit + arm64 64-bit)
#
# Directory Structure:
#   build/
#     ├── ipa/
#     │   ├── LegacyTG-armv7.ipa   (32-bit for iPhone 4S / 5)
#     │   ├── LegacyTG-arm64.ipa   (64-bit for iPhone 5s+)
#     │   └── LegacyTG.ipa         (Universal fat package)
#     ├── armv7/
#     │   ├── libs/                (32-bit OpenSSL, cURL, Opus static libs)
#     │   ├── tdlib/               (32-bit TDLib static libs & headers)
#     │   ├── obj/                 (32-bit object files)
#     │   └── app/                 (32-bit LegacyTG.app bundle)
#     └── arm64/
#         ├── libs/                (64-bit OpenSSL, cURL, Opus static libs)
#         ├── tdlib/               (64-bit TDLib static libs & headers)
#         ├── obj/                 (64-bit object files)
#         └── app/                 (64-bit LegacyTG.app bundle)
# ==============================================================================

ROOT_DIR   := $(shell pwd)
BUILD_DIR  := $(ROOT_DIR)/build

# DEV=1 is the build scripts/devrun.sh makes: dev mode, fixtures, bench and the
# automation URLs. Those URLs drive the app from any web page, so a build without
# it has to carry none of them: scripts/check_release.sh looks at the binary.
DEV ?= 0
ifeq ($(DEV),1)
DEV_SUFFIX := -dev
endif
MACHOFIX   := $(BUILD_DIR)/tools/machofix
APP_NAME   := LegacyTG
IPA_DIR    := $(BUILD_DIR)/ipa

IPA_FILE   := $(IPA_DIR)/$(APP_NAME).ipa
IPA_ARMV7  := $(IPA_DIR)/$(APP_NAME)-armv7$(DEV_SUFFIX).ipa
IPA_ARM64  := $(IPA_DIR)/$(APP_NAME)-arm64$(DEV_SUFFIX).ipa

# Compiler & Toolchain
XCODE_DEV   := /Applications/Xcode-beta.app/Contents/Developer
ifneq ($(wildcard $(XCODE_DEV)),)
  XCODE_CLANG := $(XCODE_DEV)/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang
  XCODE_CXX   := $(XCODE_DEV)/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang++
  XCODE_SDK   := $(XCODE_DEV)/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk
else
  XCODE_CLANG := $(shell which clang)
  XCODE_CXX   := $(shell which clang++)
  XCODE_SDK   :=
endif

SDK_PATH    := $(BUILD_DIR)/sdks/iPhoneOS15.6.sdk
ifeq ($(wildcard $(SDK_PATH)),)
  SDK_PATH  := $(BUILD_DIR)/sdks/iPhoneOS12.4.sdk
endif
ifeq ($(wildcard $(SDK_PATH)),)
  SDK_PATH  := $(BUILD_DIR)/sdks/iPhoneOS9.3.sdk
endif
ifeq ($(wildcard $(SDK_PATH)),)
  SDK_PATH  := $(XCODE_SDK)
endif

# C++ stdlib include path
ifneq ($(wildcard $(SDK_PATH)/usr/include/c++/v1),)
  CXX_STDLIB_INC := -stdlib=libc++
else ifneq ($(wildcard $(XCODE_SDK)/usr/include/c++/v1),)
  CXX_STDLIB_INC := -isystem $(XCODE_SDK)/usr/include/c++/v1
else
  CXX_STDLIB_INC := -stdlib=libc++
endif

CC  := $(shell command -v ccache 2>/dev/null) $(XCODE_CLANG)
CXX := $(shell command -v ccache 2>/dev/null) $(XCODE_CXX)

MIN_IOS   := -miphoneos-version-min=6.0

# Every src subdirectory is on the include path: headers are imported by basename.
SRC_INCLUDES := $(addprefix -I,$(shell find $(ROOT_DIR)/src -type d))

# Include Flags
INCLUDES  := -I$(ROOT_DIR)/vendor/include \
             -I$(ROOT_DIR)/src/Compat \
             $(SRC_INCLUDES) \
             -I$(ROOT_DIR)/third_party \
             -I$(ROOT_DIR)/third_party/nanosvg \
             -I$(ROOT_DIR)/third_party/libvpx/include \
             -I$(ROOT_DIR)/third_party/nestegg/include \
             -I$(ROOT_DIR)/third_party/ogg \
             -I$(ROOT_DIR)/third_party/ogg/ogg \
             -I$(ROOT_DIR)/third_party/opus/include \
             -I$(ROOT_DIR)/third_party/opus/include/opus \
             -I$(ROOT_DIR)/third_party/opusenc \
             -I$(ROOT_DIR)/third_party/opusfile \
             -I$(ROOT_DIR)/tdlib/td \
             -I$(ROOT_DIR)/tdlib/include \
             -I$(BUILD_DIR)/armv7/tdlib/include \
             -I$(BUILD_DIR)/arm64/tdlib/include \
             -I$(ROOT_DIR)/vendor/libs \
             -F$(ROOT_DIR)/vendor/libs

DEFINES   :=
ifeq ($(DEV),1)
DEFINES   += -DTG_DEV=1
ADD_DEV_SCHEMES = /usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0 dict" \
	-c "Add :CFBundleURLTypes:0:CFBundleURLName string org.legacy.itg.devrun" \
	-c "Add :CFBundleURLTypes:0:CFBundleURLSchemes array" \
	-c "Add :CFBundleURLTypes:0:CFBundleURLSchemes:0 string legacytg" \
	-c "Add :CFBundleURLTypes:0:CFBundleURLSchemes:1 string itglegacy" "$(1)"
else
ADD_DEV_SCHEMES = true
endif

WEBP_ARMV7 := -F$(ROOT_DIR)/vendor/libs -framework WebP
WEBP_ARM64 := -L$(BUILD_DIR)/arm64/libs -lwebp

# FFmpeg is the Vintage software decoder and exists for armv7 only. The arm64
# compile must never see these headers: TGSoftVideoPlayer compiles a stub there.
ARMV7_FFMPEG      := $(BUILD_DIR)/armv7/ffmpeg
ARMV7_FFMPEG_INC  := -I$(ARMV7_FFMPEG)/include
ARMV7_FFMPEG_LIBS := $(ARMV7_FFMPEG)/lib/libavformat.a \
                     $(ARMV7_FFMPEG)/lib/libavcodec.a \
                     $(ARMV7_FFMPEG)/lib/libavutil.a
#        ^^ backed by the repacked archive from scripts/repack_arm64_libs.sh

FRAMEWORKS := -framework UIKit -framework Accelerate -framework Foundation -framework QuickLook \
              -framework SystemConfiguration -framework CoreGraphics \
              -framework QuartzCore -framework MediaPlayer \
              -framework AVFoundation -framework AudioToolbox \
              -framework CoreMedia -framework CoreVideo -framework AddressBook \
              -framework AddressBookUI -framework MobileCoreServices \
              -framework CoreLocation -framework MapKit \
              -framework CoreTelephony -framework CoreImage \
              -framework CoreText -framework AssetsLibrary \
              -framework ImageIO -framework Security -framework OpenGLES \
              -framework VideoToolbox


# TDLib is loaded at runtime from libtdjson.dylib, never linked.
# armv7 loads TDLib from a dylib and links none of it: static, its __TEXT goes
# past 19MB and a Thumb BL only reaches 16, which this linker cannot bridge.
# arm64 has no such limit, and no arm64 dylib was ever built - so it links the
# static libraries it already has. That is why this is per-architecture.
TDLIB_LIBS :=
# -u forces each entry point in even though nothing references it at link
# time: the app reaches TDLib through dlsym, so -dead_strip would otherwise
# throw the whole library away and leave a binary that links but cannot talk.
TDLIB_KEEP_ARM64 := -Wl,-u,_td_json_client_create -Wl,-u,_td_json_client_send \
                    -Wl,-u,_td_json_client_receive -Wl,-u,_td_json_client_execute \
                    -Wl,-u,_td_json_client_destroy
TDLIB_LIBS_ARM64 := $(TDLIB_KEEP_ARM64) \
                    -ltdjson_static -ltdjson_private -ltdclient -ltdcore \
                    -ltdapi -ltddb -ltdactor -ltdnet -ltdmtproto -ltdsqlite \
                    -ltde2e -ltdutils -ltdtl -lssl
# libcrypto: TDLib brings its own copy inside the dylib, but libtgvoip is
# linked into the app and needs AES and SHA here.
DEPS_LIBS  := -lopus -lvpx -lstdc++ -lz -lcrypto
# 9.0.0 needs DTLS, which lives in libssl. The armv7 tree has it beside
# libcrypto; arm64 already names -lssl on its TDLib link line.
ARMV7_SSL_LIBS := -L$(BUILD_DIR)/armv7/openssl -lssl

# ------------------------------------------------------------------------------
# Source Files
# ------------------------------------------------------------------------------
# libtgvoip - voice calls. Public domain (UNLICENSE), vendored because there is
# no armv7 iOS build of it anywhere. The WebRTC DSP is left out: TGVOIP_NO_DSP
# drops echo cancellation and noise suppression, which an A5 cannot afford and
# whose sources this fork does not fully carry anyway.
VOIP_SRC_CXX := \
	third_party/libtgvoip/VoIPController.cpp \
	third_party/libtgvoip/VoIPServerConfig.cpp \
	third_party/libtgvoip/logging.cpp \
	third_party/libtgvoip/json11.cpp \
	third_party/libtgvoip/video/ScreamCongestionController.cpp \
	third_party/libtgvoip/JitterBuffer.cpp \
	third_party/libtgvoip/OpusEncoder.cpp \
	third_party/libtgvoip/OpusDecoder.cpp \
	third_party/libtgvoip/NetworkSocket.cpp \
	third_party/libtgvoip/CongestionControl.cpp \
	third_party/libtgvoip/EchoCanceller.cpp \
	third_party/libtgvoip/MessageThread.cpp \
	third_party/libtgvoip/Buffers.cpp \
	third_party/libtgvoip/BlockingQueue.cpp \
	third_party/libtgvoip/MediaStreamItf.cpp \
	third_party/libtgvoip/PacketReassembler.cpp \
	third_party/libtgvoip/audio/AudioIO.cpp \
	third_party/libtgvoip/audio/AudioInput.cpp \
	third_party/libtgvoip/audio/AudioOutput.cpp \
	third_party/libtgvoip/audio/Resampler.cpp \
	third_party/libtgvoip/os/darwin/AudioUnitIO.cpp \
	third_party/libtgvoip/os/darwin/AudioInputAudioUnit.cpp \
	third_party/libtgvoip/os/darwin/AudioOutputAudioUnit.cpp \
	third_party/libtgvoip/os/posix/NetworkSocketPosix.cpp

VOIP_SRC_MM := \
	third_party/libtgvoip/os/darwin/DarwinSpecific.mm

VOIP_FLAGS := -DTGVOIP_NO_DSP -DWEBRTC_POSIX -DTGVOIP_USE_CUSTOM_CRYPTO \
              -I$(ROOT_DIR)/third_party/libtgvoip -Wno-everything

LIBTG_SRC_C :=

LIBTG_SRC_CXX :=

# Vendored third-party sources kept out of the app's own lists: they ride
# the same object rules, but a list that says "the app" now really does.
VENDOR_SRC_M := \
	third_party/opusenc/opusenc.m

VENDOR_SRC_C := \
	third_party/yyjson/yyjson.c \
	third_party/nanosvg/nanosvg.c \
	third_party/nestegg/nestegg.c \
	third_party/opusfile/internal.c \
	third_party/opusfile/opusfile.c \
	third_party/opusfile/info.c \
	third_party/opusfile/stream.c \
	third_party/ogg/ogg/framing.c \
	third_party/ogg/ogg/bitwise.c \
	third_party/opusenc/opus_header.c \
	third_party/opusenc/picture.c \
	third_party/opusenc/diag_range.c

APP_SRC_M := \
	src/App/AppDelegate.m \
	src/App/AppDelegate+URL.m \
	src/App/RootViewController.m \
	src/App/main.m \
	src/Features/Dev/TGDevBench.m \
	src/Features/Dev/TGDevFeedback.m \
	src/Core/Client/TGClient.m \
	src/Core/Client/TGClient+Peers.m \
	src/Core/Stores/TGStickerStore.m \
	src/Core/Stores/TGEmojiStore.m \
	src/Core/Model/TGServiceMessageText.m \
	src/Core/Model/TGMessageContentCommerce.m \
	src/Core/Model/TGMessageContentInteractive.m \
	src/Core/Model/TGMessageCard.m \
	src/Core/Model/TGLiveLocation.m \
	src/Core/Model/TGComposerText.m \
	src/Core/Model/TGGiftFlatten.m \
	src/Core/Model/TGPinnedLine.m \
	src/Core/Stores/TGCustomEmojiStore.m \
	src/Core/Stores/TGMediaStore.m \
	src/Core/Stores/TGMemberAvatarStore.m \
	src/Core/Stores/TGPeerStore.m \
	src/Core/Client/TGClient+Auth.m \
	src/Core/Client/Messages/TGClient+MessagesUpload.m \
	src/Core/Client/Messages/TGClient+Messages.m \
	src/Core/Client/Messages/TGClient+MessageRecord.m \
	src/Core/Client/Messages/TGClient+InlineMessages.m \
	src/Core/Model/TGMessageFlatten.m \
	src/Core/Client/TGClient+MessageMeta.m \
	src/Core/Client/TGClient+SavedMessages.m \
	src/Core/Client/TGClient+Notifications.m \
	src/Core/Model/TGStatusText.m \
	src/Core/Support/TGBase64.m \
	src/Core/Support/TGLocalization.m \
	src/Core/Support/TGQRCode.m \
	src/App/TGNavController.m \
	src/Core/Client/Account/TGClient+AccountContacts.m \
	src/Core/Client/Account/TGClient+AccountPeople.m \
	src/Core/Client/Account/TGClient+AccountCore.m \
	src/Core/Client/Account/TGClient+AccountLocalNotifications.m \
	src/Core/Client/Account/TGClient+AccountSettings.m \
	src/Core/Client/Account/TGClient+AccountReactions.m \
	src/Core/Client/Account/TGClient+AccountOptions.m \
	src/Core/Client/Account/TGClient+AccountAutosave.m \
	src/Core/Client/Account/TGClient+AccountProfileMedia.m \
	src/Core/Client/Account/TGClient+AccountTwoStep.m \
	src/Core/Client/Account/TGClient+AccountRest.m \
	src/Core/Client/Account/TGClient+AccountSupport.m \
	src/Core/Client/TGClient+Accounts.m \
	src/Core/Client/TGClient+Appearance.m \
	src/Core/Client/TGClient+Diagnostics.m \
	src/Core/Support/TGDatabaseKey.m \
	src/Core/Client/TGClient+Profile.m \
	src/Core/Client/TGClient+ProfileAudio.m \
	src/Core/Client/TGClient+EmojiStatus.m \
	src/Core/Client/TGClient+TextStyles.m \
	src/Core/Client/TGClient+DirectMessages.m \
	src/Core/Client/TGClient+Dice.m \
	src/Core/Client/TGClient+Affiliate.m \
	src/Core/Client/TGClient+BotSession.m \
	src/Core/Client/TGClient+GameScores.m \
	src/Core/Client/TGClient+Support.m \
	src/Core/Client/TGClient+TestHarness.m \
	src/Core/Client/TGClient+Proxy.m \
	src/Core/Client/TGClient+Groups.m \
	src/Core/Client/TGClient+GroupCalls.m \
	src/Core/Client/TGClient+Usernames.m \
	src/Core/Client/TGClient+Payments.m \
	src/Core/Client/TGClient+Calls.m \
	src/Core/Client/TGClient+Websites.m \
	src/Core/Client/TGClient+BotTools.m \
	src/Core/Client/TGClient+Language.m \
	src/Core/Client/TGClient+Search.m \
	src/Core/Client/Stories/TGClient+StoriesSupport.m \
	src/Core/Client/Stories/TGClient+StoriesFeed.m \
	src/Core/Client/Stories/TGClient+StoriesViewer.m \
	src/Core/Client/Stories/TGClient+StoriesPosting.m \
	src/Core/Client/Stories/TGClient+StoriesAlbums.m \
	src/Core/Client/Stories/TGClient+StoriesInteractions.m \
	src/Core/Client/Stories/TGClient+StoriesNotifications.m \
	src/Core/Client/Stories/TGClient+StoriesDiscovery.m \
	src/Core/Client/Stories/TGClient+StoriesStealth.m \
	src/Core/Client/Stories/TGClient+StoriesLive.m \
	src/Core/Client/TGClient+Business.m \
	src/Core/Client/Features/TGClient+FeatureSupport.m \
	src/Core/Client/Features/TGClient+Communities.m \
	src/Core/Client/Features/TGClient+QuickReplies.m \
	src/Core/Client/Features/TGClient+Checklists.m \
	src/Core/Client/Features/TGClient+SuggestedPosts.m \
	src/Core/Client/Features/TGClient+AITools.m \
	src/Core/Client/Audit/TGClient+AuditSupport.m \
	src/Core/Client/Audit/TGClient+Ads.m \
	src/Core/Client/Audit/TGClient+Speech.m \
	src/Core/Client/Audit/TGClient+Environment.m \
	src/Core/Client/Audit/TGClient+OwnedBots.m \
	src/Core/Client/Audit/TGClient+WebApps.m \
	src/Core/Client/Audit/TGClient+OAuth.m \
	src/Core/Client/Audit/TGClient+BusinessBot.m \
	src/Core/Client/Audit/TGClient+Premium.m \
	src/Core/Client/Audit/TGClient+Boosts.m \
	src/Core/Client/Audit/TGClient+Revenue.m \
	src/Core/Client/Audit/TGClient+Discovery.m \
	src/Core/Client/Audit/TGClient+Stars.m \
	src/Core/Client/Audit/TGClient+Gifts.m \
	src/Core/Client/TGClient+ChatTools.m \
	src/Core/Client/TGClient+Downloads.m \
	src/Core/Client/TGClient+Secret.m \
	src/Core/Client/TGClient+Stickers.m \
	src/Core/Client/TGClient+Updates.m \
	src/Core/Platform/TGDevice.m \
	src/Core/Platform/TGCapabilities.m \
	src/Core/Style/TGTheme.m \
	src/Core/Style/TGTheme+Colours.m \
	src/Core/Style/TGTheme+Gradients.m \
	src/Core/Style/TGTheme+Effects.m \
	src/Core/Style/TGTheme+Drawing.m \
	src/Core/Style/TGStyle.m \
	src/Core/Style/TGTextDraw.m \
	src/Core/Platform/TGPerf.m \
	src/Core/Stores/TGStickerBudget.m \
	src/Core/Stores/TGBackgroundStore.m \
	src/Core/Stores/TGUpdateStore.m \
	src/Core/Stores/TGChatThemeStore.m \
	src/Core/Style/TGThemeFile.m \
	src/Views/Icons/TGIcons.m \
	src/Views/Icons/TGIconPaths.m \
	src/Views/Icons/TGIcons+Menu.m \
	src/Views/Icons/TGIcons+Avatars.m \
	src/Views/Icons/TGIcons+Illustrations.m \
	src/Views/Icons/TGIcons+Media.m \
	src/Views/Icons/TGIcons+Chat.m \
	src/UI/Overlays/TGPopupMenu.m \
	src/UI/Overlays/TGSheet.m \
	src/UI/TGLocalizationUIKit.m \
	src/UI/Overlays/TGAlertSheet.m \
	src/Features/Chat/Views/TGMessageCardLayout.m \
	src/Features/Chat/Views/TGMessageCardView.m \
	src/Features/Profile/TGNameWithStatus.m \
	src/Features/Media/TGMediaVeilBlur.m \
	src/Features/Media/TGMediaVeil.m \
	src/UI/Overlays/TGSnackbar.m \
	src/Features/Media/TGPlayerView.m \
	src/UI/Overlays/TGEmptyView.m \
	src/UI/Overlays/TGStatusBanner.m \
	src/UI/Overlays/TGInAppNotificationBanner.m \
	src/UI/Controls/TGButton.m \
	src/UI/Controls/TGSlider.m \
	src/UI/Controls/TGTextField.m \
	src/UI/Controls/TGSegmentedControl.m \
	src/UI/Controls/TGCardView.m \
	src/UI/Controls/TGBadge.m \
	src/UI/Overlays/TGReactionPicker.m \
	src/UI/Controls/TGAvatarView.m \
	src/Features/ChatList/TGSearchViewController.m \
	src/Features/Chat/TGInstantViewController.m \
	src/Features/Dev/TGDevGalleryViewController.m \
	src/UI/Controllers/TGPlaceholderViewController.m \
	src/Features/Auth/TGQRViewController.m \
	src/UI/Format/TGUIFormat.m \
	src/Features/Chat/TGPollPresentation.m \
	src/Features/Chat/Core/TGChatParityModel.m \
	src/Features/Chat/Core/TGChatActionMenuModel.m \
	src/Features/Chat/TGChecklistPresentation.m \
	src/Features/Auth/TGLoginViewController.m \
	src/Features/Auth/TGLoginViewController+Phone.m \
	src/Features/Auth/TGLoginViewController+Steps.m \
	src/Features/ChatList/TGChatListViewController.m \
	src/Features/ChatList/Core/TGChatListSnapshot.m \
	src/Features/ChatList/Core/TGChatListLifecycle.m \
	src/Features/ChatList/Core/TGChatListHeader.m \
	src/Features/ChatList/Core/TGChatListFolders.m \
	src/Features/ChatList/Core/TGChatListCompose.m \
	src/Features/ChatList/Core/TGChatListReload.m \
	src/Features/ChatList/Core/TGChatListTable.m \
	src/Features/ChatList/Core/TGChatListSelection.m \
	src/Features/ChatList/TGChatListViewController+Actions.m \
	src/Features/ChatList/TGChatListViewController+Search.m \
	src/Features/Chat/Views/TGRecordBar.m \
	src/Core/Platform/TGGhostMode.m \
	src/Core/Stores/TGPlaybackQueue.m \
	src/Core/Model/TGProfileTabs.m \
	src/Core/Platform/TGPasscode.m \
	src/Features/Settings/TGPasscodeViewController.m \
	src/Features/Stories/TGStoryCameraViewController.m \
	src/Features/Profile/TGProfileAppearanceViewController.m \
	src/Features/ChatList/TGChatListRowGeometry.m \
	src/Features/Stories/TGStoriesCell.m \
	src/Features/Chat/Views/TGEmojiData.m \
	src/Features/Chat/Views/TGEmojiPanel.m \
	src/Features/Chat/Views/EmojiPanel/TGEmojiPanelBase.m \
	src/Features/Chat/Views/EmojiPanel/TGEmojiPanelTabs.m \
	src/Features/Chat/Views/EmojiPanel/TGEmojiPanelStrip.m \
	src/Features/Chat/Views/EmojiPanel/TGEmojiPanelItems.m \
	src/Features/Chat/Views/EmojiPanel/TGEmojiPanelItemsLoading.m \
	src/Features/Chat/Views/EmojiPanel/TGEmojiPanelSearch.m \
	src/Features/Chat/Views/EmojiPanel/TGEmojiPanelGridLayout.m \
	src/Features/Chat/Views/EmojiPanel/TGEmojiPanelGridImages.m \
	src/Features/Chat/Views/EmojiPanel/TGEmojiPanelEmojiCards.m \
	src/Features/Chat/Views/EmojiPanel/TGEmojiPanelStickerSheets.m \
	src/Features/Chat/Views/EmojiPanel/TGEmojiPanelTaps.m \
	src/Features/Chat/Views/EmojiPanel/TGEmojiPanelGIFSearch.m \
	src/Features/Chat/Views/TGAttachSheet.m \
	src/Features/Profile/TGMemberCell.m \
	src/UI/Messages/TGMessageBubbleCell.m \
	src/UI/Messages/TGMessageServiceCell.m \
	src/UI/Messages/TGMessageDateHeaderCell.m \
	src/UI/Messages/TGMessageUnreadSeparatorCell.m \
	src/UI/Messages/TGMessageCellKind.m \
	src/UI/Messages/TGMessageCellFactory.m \
	src/Features/Dev/TGDevShowcase.m \
	src/Features/Dev/TGDevModeViewController.m \
	src/Features/Chat/TGChatViewController.m \
	src/Features/Chat/Core/TGChatViewLayout.m \
	src/Features/Chat/Core/TGChatViewData.m \
	src/Features/Chat/Core/TGChatViewPinned.m \
	src/Features/Chat/Core/TGChatViewTaps.m \
	src/Features/Chat/Core/TGChatViewDocumentDelegate.m \
	src/Features/Chat/Core/TGChatViewPagination.m \
	src/Features/Chat/Selection/TGChatViewController+Selection.m \
	src/Features/Chat/Composer/TGChatAudioVoice.m \
	src/Features/Chat/Composer/TGChatAudioVideoNotes.m \
	src/Features/Chat/Composer/TGChatAudioPlayback.m \
	src/Features/Chat/Search/TGChatViewController+Search.m \
	src/Features/Chat/Composer/TGChatViewController+Bots.m \
	src/Features/Chat/Actions/TGChatActionsMessageActions.m \
	src/Features/Chat/Actions/TGChatActionsHoldMenu.m \
	src/Features/Chat/Actions/TGChatViewController+Attachments.m \
	src/Features/Chat/Actions/TGChatViewController+MessageSheets.m \
	src/Features/Chat/Rendering/TGChatViewController+Layout.m \
	src/Features/Chat/Rendering/TGChatViewController+Cells.m \
	src/Features/Chat/Rendering/TGChatViewController+ServiceCells.m \
	src/Features/Chat/Composer/TGChatViewController+AudioCells.m \
	src/Features/Chat/Composer/TGChatViewController+MediaCells.m \
	src/Features/Chat/Composer/TGChatViewController+Input.m \
	src/Features/Chat/Composer/TGChatViewController+Media.m \
	src/Features/Chat/Rendering/TGChatViewController+Chrome.m \
	src/Features/Chat/TGMessageAudienceViewController.m \
	src/Features/Stories/TGStoryViewerViewController.m \
	src/Features/Stories/TGStoryComposerViewController.m \
	src/Features/Stories/TGStoryInfoViewController.m \
	src/Features/Stories/TGStoryAlbumsViewController.m \
	src/Features/Stories/TGStoryArchiveViewController.m \
	src/Features/Stories/TGStorySettingsViewController.m \
	src/Features/Stories/TGStoriesMenuViewController.m \
	src/Features/Profile/TGEmojiStatusViewController.m \
	src/Features/Profile/TGProfileAudioViewController.m \
	src/Features/Settings/TGTextStylesViewController.m \
	src/Features/Chat/TGDMTopicsViewController.m \
	src/Features/Chat/TGDMTopicViewController.m \
	src/Features/Channels/TGSimilarChannelsViewController.m \
	src/Features/Chat/TGDiceViewController.m \
	src/Features/Chat/TGEphemeralViewController.m \
	src/Features/Media/TGVideoNoteViewController.m \
	src/Features/Stories/TGPublicStoriesViewController.m \
	src/Features/Stories/TGLiveStoryViewController.m \
	src/Features/Business/TGBusinessBaseViewController.m \
	src/Features/Business/TGBusinessViewController.m \
	src/Features/Business/Pages/TGBusinessProfileViewController.m \
	src/Features/Business/Pages/TGBusinessChatLinksViewController.m \
	src/Features/Business/Pages/TGBusinessGreetingViewController.m \
	src/Features/Business/Pages/TGBusinessAwayViewController.m \
	src/Features/Business/Pages/TGBusinessHoursViewController.m \
	src/Features/Business/Pages/TGBusinessLocationViewController.m \
	src/Features/Business/Pages/TGBusinessIntroViewController.m \
	src/Features/Business/TGBusinessViewControllerSupport.m \
	src/Features/Business/TGBusinessMessagesViewController.m \
	src/Features/Groups/TGAntiSpamViewController.m \
	src/Features/Dev/TGDevWebProxyCarrierViewController.m \
	src/Features/Settings/TGSettingsViewController+Tier2.m \
	src/Features/Contacts/TGContactsViewController.m \
	src/Features/Contacts/TGContactSort.m \
	src/Features/Contacts/TGCloseFriendsViewController.m \
	src/Features/Contacts/TGNewContactViewController.m \
	src/Features/Groups/TGTopicsViewController.m \
	src/Features/Chat/TGSavedTopicsViewController.m \
	src/Features/Media/TGStickerPacksViewController.m \
	src/Features/Media/TGStickerEditorViewController.m \
	src/Features/Media/TGStickerGalleryViewController.m \
	src/Features/Chat/TGScheduledViewController.m \
	src/Features/Chat/TGForwardPicker.m \
	src/Features/Calls/Views/TGCallMiniBar.m \
	src/Features/Calls/TGCallViewController.m \
	src/Features/Settings/TGActiveNotificationsViewController.m \
	src/UI/Controllers/TGListViewController.m \
	src/UI/Controllers/TGViewController.m \
	src/UI/Controllers/TGTableViewController.m \
	src/UI/Controls/TGTableViewCell.m \
	src/UI/Controllers/TGFormViewController.m \
	src/Features/Settings/TGNetworkViewController.m \
	src/Features/Chat/TGChatToolsViewController.m \
	src/Features/Profile/TGProfileViewController.m \
	src/Features/Profile/Core/TGProfileLifecycle.m \
	src/Features/Profile/Core/TGProfileHeader.m \
	src/Features/Profile/Core/TGProfileData.m \
	src/Features/Profile/Core/TGProfileLogic.m \
	src/Features/Profile/Core/TGProfileDetails.m \
	src/Features/Profile/Core/TGProfileAvatars.m \
	src/Features/Profile/Core/TGProfileTable.m \
	src/Features/Profile/TGProfileViewController+Actions.m \
	src/Features/Profile/TGProfileViewController+Media.m \
	src/Features/Profile/TGProfileViewController+Tier2.m \
	src/Features/BotsPayments/TGGiftViewController.m \
	src/Features/Profile/TGEditProfileViewController.m \
	src/Features/Profile/TGProfileBirthdaySuggestViewController.m \
	src/Features/Settings/TGUsernameSettingsViewController.m \
	src/Features/Settings/TGNotificationCategoryViewController.m \
	src/Features/Groups/Views/TGGroupSwitch.m \
	src/Features/Groups/Core/TGGroupLogic.m \
	src/Features/Groups/Core/TGGroupBase.m \
	src/Features/Groups/Core/TGGroupData.m \
	src/Features/Groups/Core/TGGroupSections.m \
	src/Features/Groups/Core/TGGroupSwitches.m \
	src/Features/Groups/TGGroupSettingsViewController.m \
	src/Features/Groups/Core/TGGroupActions.m \
	src/Features/Groups/Core/TGGroupIdentity.m \
	src/Features/Groups/Core/TGGroupMembers.m \
	src/Features/Groups/TGMemberListViewController.m \
	src/Features/Groups/Core/TGGroupPermissions.m \
	src/Features/Groups/Core/TGGroupTools.m \
	src/Features/Groups/Core/TGGroupInvites.m \
	src/Features/Groups/Core/TGGroupUsernames.m \
	src/Features/Calls/TGGroupCallViewController.m \
	src/Features/Calls/TGGroupCallParticipantsViewController.m \
	src/Features/Calls/TGGroupCallParticipantCell.m \
	src/Features/Calls/TGVideoChatSetupViewController.m \
	src/Features/Calls/TGVideoChatStreamViewController.m \
	src/Features/Calls/TGCallMessagesViewController.m \
	src/Features/Groups/TGGroupMemberActions.m \
	src/Features/Groups/TGAdminRightsViewController.m \
	src/Features/Settings/TGDeviceViewController.m \
	src/Features/Settings/TGStorageViewController.m \
	src/Features/Media/TGFileInfoViewController.m \
	src/Features/Dev/TGDevFileToolsViewController.m \
	src/Features/Settings/TGSessionsViewController.m \
	src/Features/Settings/TGWebsitesViewController.m \
	src/Features/Auth/TGTermsViewController.m \
	src/Features/Profile/TGProfilePhotosViewController.m \
	src/Features/Settings/TGBackgroundsViewController.m \
	src/Features/Settings/TGBackgroundEditorViewController.m \
	src/Features/Settings/TGPrivacyRuleViewController.m \
	src/Features/Settings/TGUserPickerViewController.m \
	src/Features/Settings/TGSettingsViewController.m \
	src/Features/Settings/Pages/TGSettingsPagesCore.m \
	src/Features/Settings/Pages/TGSettingsPagesPayments.m \
	src/Features/Settings/Pages/TGSettingsPageModels.m \
	src/Features/Settings/TGSettingsViewController+AppearancePages.m \
	src/Features/Settings/TGSettingsViewController+PrivacyPages.m \
	src/Features/Settings/TGSettingsViewController+NetworkPages.m \
	src/Features/Settings/TGSettingsViewController+Actions.m \
	src/Features/Settings/TGSettingsViewController+Tier2.m \
	src/UI/Rows/TGRows.m \
	src/UI/Rows/TGRowCell.m \
	src/UI/Rows/TGGridRowCell.m \
	src/UI/Rows/TGPeerRowCell.m \
	src/UI/Rows/TGFieldRowCell.m \
	src/UI/Rows/TGChatRowCell.m \
	src/UI/Rows/TGStoryStripRowCell.m \
	src/UI/Rows/TGMessageResultRowCell.m \
	src/UI/Rows/TGPictureRowCell.m \
	src/UI/Rows/TGTabStripRowCell.m \
	src/UI/Controls/TGProfileHeaderView.m \
	src/UI/Rows/TGProfileHeaderRowCell.m \
	src/UI/Rows/TGChatPreviewRowCell.m \
	src/UI/Rows/TGThemeCardsRowCell.m \
	src/UI/Rows/TGThemeGridRowCell.m \
	src/UI/Controllers/TGRowsViewController.m \
	src/UI/Controllers/TGRowsDataSource.m \
	src/UI/Controllers/TGFeatureListViewController.m \
	src/Features/Dev/TGDevHubViewController.m \
	src/Features/Groups/TGCommunitiesViewController.m \
	src/Features/Groups/TGCommunityViewController.m \
	src/Features/Chat/TGQuickRepliesViewController.m \
	src/Features/Chat/TGQuickReplyMessagesViewController.m \
	src/Features/Chat/TGChecklistViewController.m \
	src/Features/Chat/TGSuggestedPostViewController.m \
	src/Features/Chat/TGAiComposeViewController.m \
	src/Features/Chat/TGMessageToolsViewController.m \
	src/Features/BotsPayments/TGSponsoredMessagesViewController.m \
	src/Features/Dev/TGDevEnvironmentViewController.m \
	src/Features/Dev/TGDevBotConsoleViewController.m \
	src/Features/BotsPayments/TGStarsGiftsViewController.m \
	src/Features/Dev/TGDevTestHarnessViewController.m \
	src/Features/BotsPayments/TGAffiliateProgramsViewController.m \
	src/Features/Chat/TGGameScoresViewController.m \
	src/Features/Settings/TGSupportInfoViewController.m \
	src/Features/Settings/TGUpdateInfoViewController.m \
	src/Audio/TGVoiceDecoder.m \
	src/Audio/TGStreamingVoicePlayer.m \
	src/CallEngine/Network/TGCallIce.m \
	src/CallEngine/Network/TGCallStun.m \
	src/CallEngine/Signaling/TGCallMessages.m \
	src/CallEngine/Network/TGCallReflector.m \
	src/CallEngine/Signaling/TGCallV2Signaling.m \
	src/CallEngine/Signaling/TGCallV2Session.m \
	src/CallEngine/Signaling/TGCallDtls.m \
	src/CallEngine/Media/TGCallVideoRtp.m \
	src/Media/UIImage+WebP.m \
	src/Media/TGPatternImage.m \
	src/Media/TGStickerImage.m \
	src/Media/TGWebMDecoder.m \
	src/Media/TGSoftVideoPlayer.m \
	src/Features/Media/TGMediaViewer.m \
	src/Features/Media/Views/TGMediaPlayerView.m \
	src/Features/Media/Core/TGMediaViewerBase.m \
	src/Features/Media/Core/TGMediaViewerPresenting.m \
	src/Features/Media/Core/TGMediaViewerTransitions.m \
	src/Features/Media/Core/TGMediaViewerChrome.m \
	src/Features/Media/Core/TGMediaViewerPages.m \
	src/Features/Media/Core/TGMediaViewerProgress.m \
	src/Features/Media/Core/TGMediaViewerVideo.m \
	src/Features/Media/Core/TGMediaViewerMoreSheet.m \
	src/Features/Media/Core/TGMediaViewerSaving.m \
	src/Audio/TGMusicPlayer.m \
	src/Audio/TGVideoNoteRecorder.m

# TGCall.mm sits with the app, not with the vendored libtgvoip: it is the
# app's call protocol over the engine. The %.mm rule carries VOIP_FLAGS for
# every .mm file, so the objects come out identical either way.
APP_SRC_MM := \
	src/Audio/TGVoiceRecorder.mm \
	src/CallEngine/Media/TGCallAudioEngine.mm \
	src/CallEngine/Media/TGCallVideoEngine.mm \
	src/CallEngine/TGCall.mm \
	src/Core/Stores/TGImageLruCache.mm \
	src/Core/Client/Chats/TGClient+ChatsSupport.mm \
	src/Core/Client/Chats/TGClient+Chats.mm \
	src/Core/Client/Chats/TGClient+ChatMembers.mm \
	src/Core/Client/Chats/TGClient+ChatContacts.mm \
	src/Core/Client/Chats/TGClient+ChatReporting.mm \
	src/Core/Client/Chats/TGClient+Recents.mm \
	src/Core/Client/Chats/TGClient+ChatSearch.mm \
	src/Core/Client/Chats/TGClient+ChatFolders.mm \
	src/Core/Client/TGClient+Files.mm \
	src/Core/Stores/TGStickerPack.mm \
	src/Core/Support/TGJson.mm \
	src/Core/Stores/TGOptions.mm \
	src/Core/Stores/TGMessageStreamStore.mm \
	src/Core/Support/TGUpdateBatcher.mm \
	src/Features/Chat/Views/TGMessageLayout.mm \
	src/Features/Media/TGLottieView.mm

APP_SRC_C := \
	src/Core/Support/TGUpdateType.c \
	src/Media/TGSoftVideoClock.c \
	src/Views/Icons/TGSVGPath.c \
	src/Core/Platform/TGSampler.c \
	src/Compat/tlv_polyfill.c \
	src/CallEngine/Crypto/TGCallCrypto.c \
	src/CallEngine/Crypto/TGCallSrtp.c

# Object mapping for armv7
# Reached only from dev mode.
DEV_SRC_M := \
	src/Features/Stories/TGStoriesMenuViewController.m \
	src/Features/Stories/TGStoryArchiveViewController.m \
	src/Features/Dev/TGDevBench.m \
	src/Features/Dev/TGDevShowcase.m \
	src/Features/Dev/TGDevModeViewController.m \
	src/Features/Dev/TGDevGalleryViewController.m \
	src/Features/Dev/TGDevTestHarnessViewController.m \
	src/Features/Dev/TGDevEnvironmentViewController.m \
	src/Features/Dev/TGDevHubViewController.m \
	src/Features/Groups/TGCommunitiesViewController.m \
	src/Features/Groups/TGCommunityViewController.m \
	src/Features/Dev/TGDevWebProxyCarrierViewController.m \
	src/Features/Settings/TGTextStylesViewController.m \
	src/Features/Chat/TGMessageToolsViewController.m
ifneq ($(DEV),1)
APP_SRC_M := $(filter-out $(DEV_SRC_M),$(APP_SRC_M))
endif

ARMV7_OBJ_DIR := $(BUILD_DIR)/armv7/obj$(DEV_SUFFIX)
ARMV7_LIBTG_OBJS := $(patsubst %.c,$(ARMV7_OBJ_DIR)/%.o,$(LIBTG_SRC_C)) \
                    $(patsubst %.cpp,$(ARMV7_OBJ_DIR)/%.o,$(LIBTG_SRC_CXX))
ARMV7_VOIP_OBJS  := $(patsubst %.cpp,$(ARMV7_OBJ_DIR)/%.o,$(VOIP_SRC_CXX)) \
                    $(patsubst %.mm,$(ARMV7_OBJ_DIR)/%.o,$(VOIP_SRC_MM))
ARMV7_APP_OBJS   := $(patsubst %.m,$(ARMV7_OBJ_DIR)/%.o,$(APP_SRC_M)) \
                    $(patsubst %.mm,$(ARMV7_OBJ_DIR)/%.o,$(APP_SRC_MM)) \
                    $(patsubst %.c,$(ARMV7_OBJ_DIR)/%.o,$(APP_SRC_C)) \
                    $(patsubst %.m,$(ARMV7_OBJ_DIR)/%.o,$(VENDOR_SRC_M)) \
                    $(patsubst %.c,$(ARMV7_OBJ_DIR)/%.o,$(VENDOR_SRC_C)) \
                    $(ARMV7_VOIP_OBJS)
ARMV7_ALL_OBJS   := $(ARMV7_LIBTG_OBJS) $(ARMV7_APP_OBJS)

# Object mapping for arm64
ARM64_OBJ_DIR := $(BUILD_DIR)/arm64/obj$(DEV_SUFFIX)
ARM64_LIBTG_OBJS := $(patsubst %.c,$(ARM64_OBJ_DIR)/%.o,$(LIBTG_SRC_C)) \
                    $(patsubst %.cpp,$(ARM64_OBJ_DIR)/%.o,$(LIBTG_SRC_CXX))
ARM64_VOIP_OBJS  := $(patsubst %.cpp,$(ARM64_OBJ_DIR)/%.o,$(VOIP_SRC_CXX)) \
                    $(patsubst %.mm,$(ARM64_OBJ_DIR)/%.o,$(VOIP_SRC_MM))
ARM64_APP_OBJS   := $(patsubst %.m,$(ARM64_OBJ_DIR)/%.o,$(APP_SRC_M)) \
                    $(patsubst %.mm,$(ARM64_OBJ_DIR)/%.o,$(APP_SRC_MM)) \
                    $(patsubst %.c,$(ARM64_OBJ_DIR)/%.o,$(APP_SRC_C)) \
                    $(patsubst %.m,$(ARM64_OBJ_DIR)/%.o,$(VENDOR_SRC_M)) \
                    $(patsubst %.c,$(ARM64_OBJ_DIR)/%.o,$(VENDOR_SRC_C)) \
                    $(ARM64_VOIP_OBJS)
ARM64_ALL_OBJS   := $(ARM64_LIBTG_OBJS) $(ARM64_APP_OBJS)

# Compiler Flags per Architecture
# Header dependency files: every compile emits a .d next to the .o, so a
# changed header re-triggers the translation units that include it. Without
# this the linker happily mixes pre-rename and post-rename objects, and the
# result crashes with unrecognized selectors at runtime (2026-10-25).
CFLAGS_ARMV7    := -arch armv7 -mthumb -O2 -isysroot $(SDK_PATH) $(MIN_IOS) $(INCLUDES) $(ARMV7_FFMPEG_INC) $(DEFINES) -fPIC \
                   -MMD -MP \
                   -Wno-macro-redefined -Wno-incompatible-pointer-types -Wno-deprecated-declarations
OBJCFLAGS_ARMV7 := $(CFLAGS_ARMV7) -fobjc-arc
CXXFLAGS_ARMV7  := $(CFLAGS_ARMV7) $(CXX_STDLIB_INC) -std=c++11 -fno-use-cxa-atexit -fno-threadsafe-statics -Wno-error

CFLAGS_ARM64    := -arch arm64 -O2 -isysroot $(SDK_PATH) $(MIN_IOS) $(INCLUDES) $(DEFINES) -fPIC \
                   -MMD -MP \
                   -Wno-macro-redefined -Wno-incompatible-pointer-types -Wno-deprecated-declarations
OBJCFLAGS_ARM64 := $(CFLAGS_ARM64) -fobjc-arc
CXXFLAGS_ARM64  := $(CFLAGS_ARM64) $(CXX_STDLIB_INC) -std=c++11 -fno-use-cxa-atexit -fno-threadsafe-statics -Wno-error

# ------------------------------------------------------------------------------
# Main Targets
# ------------------------------------------------------------------------------
.PHONY: all ipa ipa-armv7 ipa-arm64 clean help

all: ipa

deploy:
	@chmod +x scripts/deploy.sh
	@./scripts/deploy.sh

deploy-sync:
	@chmod +x scripts/deploy.sh
	@./scripts/deploy.sh --sync

deploy-full:
	@chmod +x scripts/deploy.sh
	@./scripts/deploy.sh --full

ipa: ipa-armv7 ipa-arm64
	@echo "[+] Packaging universal fat IPA $(IPA_FILE)..."
	@mkdir -p "$(IPA_DIR)" "$(BUILD_DIR)/fat_app/$(APP_NAME).app"
	@cp -rf "$(BUILD_DIR)/arm64/app$(DEV_SUFFIX)/$(APP_NAME).app/"* "$(BUILD_DIR)/fat_app/$(APP_NAME).app/"
	@lipo -create "$(BUILD_DIR)/armv7/app$(DEV_SUFFIX)/$(APP_NAME).app/$(APP_NAME)" "$(BUILD_DIR)/arm64/app$(DEV_SUFFIX)/$(APP_NAME).app/$(APP_NAME)" -output "$(BUILD_DIR)/fat_app/$(APP_NAME).app/$(APP_NAME)"
	# The armv7 slice dlopens this; the arm64 slice has TDLib linked in and
	# ignores it. Packaging from the arm64 bundle alone left it out, and the
	# universal build installed on a 4S with no TDLib at all.
	@cp -f "$(BUILD_DIR)/armv7/app$(DEV_SUFFIX)/$(APP_NAME).app/libtdjson.dylib" "$(BUILD_DIR)/fat_app/$(APP_NAME).app/" 2>/dev/null || echo "[!] no armv7 libtdjson.dylib to package"
	@codesign -s - --force "$(BUILD_DIR)/fat_app/$(APP_NAME).app" 2>/dev/null || true
	@rm -rf "$(BUILD_DIR)/stage-fat"
	@mkdir -p "$(BUILD_DIR)/stage-fat/Payload"
	@cp -rf "$(BUILD_DIR)/fat_app/$(APP_NAME).app" "$(BUILD_DIR)/stage-fat/Payload/"
	@cd "$(BUILD_DIR)/stage-fat" && zip -qr "$(IPA_FILE)" Payload
	@rm -rf "$(BUILD_DIR)/stage-fat" "$(BUILD_DIR)/fat_app"
	@echo ""
	@echo "================================================================="
	@echo "  [SUCCESS] All IPA packages built successfully!"
	@echo "  Universal : $(IPA_FILE)"
	@echo "  32-bit    : $(IPA_ARMV7)"
	@echo "  64-bit    : $(IPA_ARM64)"
	@echo "================================================================="

$(MACHOFIX): tools/machofix.c
	@mkdir -p "$(BUILD_DIR)/tools"
	cc -O2 -Wall -o $@ $<

ipa-armv7: $(MACHOFIX) $(ARMV7_ALL_OBJS)
	@echo "[+] Building 32-bit armv7 app bundle..."
	@mkdir -p "$(IPA_DIR)" "$(BUILD_DIR)/armv7/app$(DEV_SUFFIX)/$(APP_NAME).app"
	$(CC) -arch armv7 -isysroot $(SDK_PATH) $(MIN_IOS) -Wl,-dead_strip -ObjC -Wl,-pagezero_size,0x1000 \
		-L$(BUILD_DIR)/armv7/libs -L$(BUILD_DIR)/armv7/tdlib/lib -L$(ROOT_DIR)/third_party/opus/lib \
		$(ARMV7_ALL_OBJS) $(FRAMEWORKS) $(WEBP_ARMV7) $(ARMV7_FFMPEG_LIBS) $(TDLIB_LIBS) $(DEPS_LIBS) $(ARMV7_SSL_LIBS) -o "$(BUILD_DIR)/armv7/app$(DEV_SUFFIX)/$(APP_NAME).app/$(APP_NAME)"
	@cp -f "$(ROOT_DIR)/resources/Info.plist" "$(BUILD_DIR)/armv7/app$(DEV_SUFFIX)/$(APP_NAME).app/Info.plist" 2>/dev/null || true
	@$(call ADD_DEV_SCHEMES,$(BUILD_DIR)/armv7/app$(DEV_SUFFIX)/$(APP_NAME).app/Info.plist)
	@cp -f "$(ROOT_DIR)/resources/fonts/"*.ttf "$(BUILD_DIR)/armv7/app$(DEV_SUFFIX)/$(APP_NAME).app/" 2>/dev/null || true
	@cp -f "$(ROOT_DIR)/resources/sounds/"*.mp3 "$(BUILD_DIR)/armv7/app$(DEV_SUFFIX)/$(APP_NAME).app/" 2>/dev/null || true
	@cp -f "$(ROOT_DIR)/resources/strings/"*.plist "$(BUILD_DIR)/armv7/app$(DEV_SUFFIX)/$(APP_NAME).app/" 2>/dev/null || true
	@cp -f "$(ROOT_DIR)/resources/"*.tgios-theme "$(BUILD_DIR)/armv7/app$(DEV_SUFFIX)/$(APP_NAME).app/" 2>/dev/null || true
	@cp -rf "$(ROOT_DIR)/resources/images/"* "$(BUILD_DIR)/armv7/app$(DEV_SUFFIX)/$(APP_NAME).app/" 2>/dev/null || true
	@# TDLib rides along as its own image: statically linked it pushes __TEXT
	@# past the 16MB armv7 thumb branch limit. Built by scripts/build_tdlib_dylib.sh.
	@cp -f "$(BUILD_DIR)/armv7/tdlib/lib/libtdjson.dylib" "$(BUILD_DIR)/armv7/app$(DEV_SUFFIX)/$(APP_NAME).app/" 2>/dev/null || echo "[!] no libtdjson.dylib - run scripts/build_tdlib_dylib.sh"
	@echo "[+] Repairing armv7 Mach-O (__PAGEZERO, LC_MAIN, Thumb bits)..."
	$(MACHOFIX) "$(BUILD_DIR)/armv7/app$(DEV_SUFFIX)/$(APP_NAME).app/$(APP_NAME)"
	@ldid -S "$(BUILD_DIR)/armv7/app$(DEV_SUFFIX)/$(APP_NAME).app/$(APP_NAME)" 2>/dev/null || true
	@# Each package stages in its own folder: under -j the three used to share
	@# build/Payload and zip each other's half-copied bundles.
	@rm -rf "$(BUILD_DIR)/stage-armv7" "$(IPA_ARMV7)"
	@mkdir -p "$(BUILD_DIR)/stage-armv7/Payload"
	@cp -rf "$(BUILD_DIR)/armv7/app$(DEV_SUFFIX)/$(APP_NAME).app" "$(BUILD_DIR)/stage-armv7/Payload/"
	@cd "$(BUILD_DIR)/stage-armv7" && zip -qr "$(IPA_ARMV7)" Payload
	@rm -rf "$(BUILD_DIR)/stage-armv7"

ipa-arm64: $(ARM64_ALL_OBJS)
	@echo "[+] Building 64-bit arm64 app bundle..."
	@mkdir -p "$(IPA_DIR)" "$(BUILD_DIR)/arm64/app$(DEV_SUFFIX)/$(APP_NAME).app"
	$(CC) -arch arm64 -isysroot $(SDK_PATH) $(MIN_IOS) -Wl,-dead_strip \
		-L$(BUILD_DIR)/arm64/libs -L$(BUILD_DIR)/arm64/tdlib64 -L$(ROOT_DIR)/third_party/opus/lib \
		$(ARM64_ALL_OBJS) $(FRAMEWORKS) $(WEBP_ARM64) $(TDLIB_LIBS_ARM64) $(DEPS_LIBS) -o "$(BUILD_DIR)/arm64/app$(DEV_SUFFIX)/$(APP_NAME).app/$(APP_NAME)"
	@cp -f "$(ROOT_DIR)/resources/Info.plist" "$(BUILD_DIR)/arm64/app$(DEV_SUFFIX)/$(APP_NAME).app/Info.plist" 2>/dev/null || true
	@$(call ADD_DEV_SCHEMES,$(BUILD_DIR)/arm64/app$(DEV_SUFFIX)/$(APP_NAME).app/Info.plist)
	@cp -f "$(ROOT_DIR)/resources/fonts/"*.ttf "$(BUILD_DIR)/arm64/app$(DEV_SUFFIX)/$(APP_NAME).app/" 2>/dev/null || true
	@cp -f "$(ROOT_DIR)/resources/sounds/"*.mp3 "$(BUILD_DIR)/arm64/app$(DEV_SUFFIX)/$(APP_NAME).app/" 2>/dev/null || true
	@cp -f "$(ROOT_DIR)/resources/strings/"*.plist "$(BUILD_DIR)/arm64/app$(DEV_SUFFIX)/$(APP_NAME).app/" 2>/dev/null || true
	@cp -f "$(ROOT_DIR)/resources/"*.tgios-theme "$(BUILD_DIR)/arm64/app$(DEV_SUFFIX)/$(APP_NAME).app/" 2>/dev/null || true
	@cp -rf "$(ROOT_DIR)/resources/images/"* "$(BUILD_DIR)/arm64/app$(DEV_SUFFIX)/$(APP_NAME).app/" 2>/dev/null || true
	@codesign -s - --force "$(BUILD_DIR)/arm64/app$(DEV_SUFFIX)/$(APP_NAME).app" 2>/dev/null || true
	@# Each package stages in its own folder: under -j the three used to share
	@# build/Payload and zip each other's half-copied bundles.
	@rm -rf "$(BUILD_DIR)/stage-arm64" "$(IPA_ARM64)"
	@mkdir -p "$(BUILD_DIR)/stage-arm64/Payload"
	@cp -rf "$(BUILD_DIR)/arm64/app$(DEV_SUFFIX)/$(APP_NAME).app" "$(BUILD_DIR)/stage-arm64/Payload/"
	@cd "$(BUILD_DIR)/stage-arm64" && zip -qr "$(IPA_ARM64)" Payload
	@rm -rf "$(BUILD_DIR)/stage-arm64"

# ------------------------------------------------------------------------------
# Object Compilation Rules (32-bit armv7)
# ------------------------------------------------------------------------------
$(ARMV7_OBJ_DIR)/%.o: %.c
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS_ARMV7) -c $< -o $@

$(ARMV7_OBJ_DIR)/%.o: %.m
	@mkdir -p $(dir $@)
	$(CC) $(OBJCFLAGS_ARMV7) -c $< -o $@

$(ARMV7_OBJ_DIR)/third_party/libtgvoip/%.o: third_party/libtgvoip/%.cpp
	@mkdir -p $(dir $@)
	$(CXX) $(subst -std=c++11,-std=c++14,$(CXXFLAGS_ARMV7)) $(VOIP_FLAGS) -c $< -o $@

$(ARMV7_OBJ_DIR)/%.o: %.mm
	@mkdir -p $(dir $@)
	$(CXX) $(subst -std=c++11,-std=c++14,$(CXXFLAGS_ARMV7)) $(VOIP_FLAGS) -fobjc-arc -c $< -o $@

$(ARMV7_OBJ_DIR)/%.o: %.cpp
	@mkdir -p $(dir $@)
	$(CXX) $(CXXFLAGS_ARMV7) -c $< -o $@

# ------------------------------------------------------------------------------
# Object Compilation Rules (64-bit arm64)
# ------------------------------------------------------------------------------
$(ARM64_OBJ_DIR)/%.o: %.c
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS_ARM64) -c $< -o $@

$(ARM64_OBJ_DIR)/%.o: %.m
	@mkdir -p $(dir $@)
	$(CC) $(OBJCFLAGS_ARM64) -c $< -o $@

$(ARM64_OBJ_DIR)/third_party/libtgvoip/%.o: third_party/libtgvoip/%.cpp
	@mkdir -p $(dir $@)
	$(CXX) $(subst -std=c++11,-std=c++14,$(CXXFLAGS_ARM64)) $(VOIP_FLAGS) -c $< -o $@

$(ARM64_OBJ_DIR)/%.o: %.mm
	@mkdir -p $(dir $@)
	$(CXX) $(subst -std=c++11,-std=c++14,$(CXXFLAGS_ARM64)) $(VOIP_FLAGS) -fobjc-arc -c $< -o $@

$(ARM64_OBJ_DIR)/%.o: %.cpp
	@mkdir -p $(dir $@)
	$(CXX) $(CXXFLAGS_ARM64) -c $< -o $@

clean:
	@rm -rf "$(BUILD_DIR)/armv7" "$(BUILD_DIR)/arm64" "$(BUILD_DIR)/fat_app" "$(BUILD_DIR)/ipa" "$(BUILD_DIR)/Payload" "$(BUILD_DIR)/tools"

# The .d files the compilers drop next to the objects carry the real header
# dependencies; include them so a header edit invalidates its .m files.
-include $(ARMV7_LIBTG_OBJS:.o=.d) $(ARMV7_APP_OBJS:.o=.d)
-include $(ARM64_LIBTG_OBJS:.o=.d) $(ARM64_APP_OBJS:.o=.d)

help:
	@echo "Available targets:"
	@echo "  make ipa         - Build universal fat IPA (armv7 + arm64)"
	@echo "  make ipa-armv7   - Build 32-bit armv7 IPA (for iPhone 4S / 5)"
	@echo "  make ipa-arm64   - Build 64-bit arm64 IPA (for iPhone 5s+)"
	@echo "  make clean       - Clean all build outputs"
