# tests/Makefile — build and run the LegacyTG call-stack test suite.
#
# Works with only macOS Command Line Tools (no full Xcode required).
#
# Targets:
#   make -f tests/Makefile test        build + run unit tests
#   make -f tests/Makefile build       compile only
#   make -f tests/Makefile clean       remove build artefacts
#
# Requirements:
#   • macOS host (arm64 or x86_64)
#   • Xcode Command Line Tools: xcode-select --install
#   • Homebrew OpenSSL 3: brew install openssl@3

ROOT    := $(shell cd "$(dir $(lastword $(MAKEFILE_LIST))).." && pwd)
BUILD   := $(ROOT)/build/tests
SRC     := $(ROOT)/src
TESTS   := $(ROOT)/tests

OPENSSL := /opt/homebrew/opt/openssl@3
CLANG   := $(shell xcrun -f clang 2>/dev/null || echo clang)
SDK     := $(shell xcrun --sdk macosx --show-sdk-path 2>/dev/null)

ARCH    := $(shell uname -m)

SRC_INCLUDES := $(addprefix -I,$(shell find $(SRC) -type d))

CFLAGS  := \
    -arch $(ARCH) \
    $(if $(SDK),-isysroot $(SDK),) \
    -I$(TESTS)/shim \
    -I$(ROOT)/vendor/include \
    -I$(SRC)/Compat \
    $(SRC_INCLUDES) \
    -I$(ROOT)/third_party \
    -I$(ROOT)/third_party/nanosvg \
    -I$(ROOT)/vendor/libs \
    -I$(ROOT)/third_party/libtgvoip \
    -I$(TESTS) \
    -I$(OPENSSL)/include \
    -fobjc-arc \
    -fmodules \
    -O0 -g \
    -DDEBUG=1 -DTG_DEV=1

LDFLAGS := \
    $(if $(SDK),-isysroot $(SDK),) \
    -L$(OPENSSL)/lib \
    -L/opt/homebrew/opt/webp/lib \
    -lcrypto \
    -lssl \
    -lwebp \
    -lz \
    -lc++ \
    -framework Foundation \
    -framework AppKit \
    -framework VideoToolbox

# ─── sources ──────────────────────────────────────────────────────────────────

# Pure C (no ARC)
C_SRCS := src/CallEngine/Crypto/TGCallCrypto.c src/CallEngine/Crypto/TGCallSrtp.c $(SRC)/Media/TGSoftVideoClock.c

# ObjC sources under test
OBJC_SRCS := \
    src/CallEngine/Network/TGCallStun.m \
    src/CallEngine/Signaling/TGCallMessages.m \
    src/CallEngine/Network/TGCallIce.m \
    src/CallEngine/Network/TGCallReflector.m \
    src/CallEngine/Signaling/TGCallV2Signaling.m \
    src/CallEngine/Signaling/TGCallV2Session.m \
    src/CallEngine/Signaling/TGCallDtls.m \
    src/CallEngine/Media/TGCallVideoRtp.m \
    src/CallEngine/Media/TGCallVideoEngine.mm \
    src/CallEngine/TGCall.mm \
    src/Features/Chat/Views/TGMessageLayout.mm \
    src/Features/Chat/Views/TGMessageCardLayout.m \
    src/UI/Messages/TGMessageCellKind.m \
    src/Core/Model/TGMessageCard.m \
    src/Core/Style/TGStyle.m \
    src/Core/Support/TGBase64.m \
    src/Core/Support/TGLocalization.m \
    src/Core/Platform/TGPerf.m \
    src/Core/Platform/TGDevice.m \
    src/Core/Platform/TGCapabilities.m

# Real TGClient sources, compiled only into the second binary: the main
# binary links a test stub of TGClient instead, which the call tests need.
CLIENT_OBJC_SRCS := \
    $(ROOT)/third_party/yyjson/yyjson.c \
    $(ROOT)/third_party/nanosvg/nanosvg.c \
    src/Media/TGPatternImage.m \
    src/Core/Support/TGBase64.m \
    src/Core/Support/TGLocalization.m \
    src/Core/Style/TGStyle.m \
    src/Features/Settings/Pages/TGSettingsPageModels.m \
    src/Features/Profile/Core/TGProfileLogic.m \
    src/Core/Support/TGUpdateType.c \
    src/Views/Icons/TGSVGPath.c \
    src/Views/Icons/TGIconPaths.m \
    src/Core/Stores/TGOptions.mm \
    src/Core/Support/TGJson.mm \
    src/Core/Client/TGClient.m \
    src/Core/Client/TGClient+Peers.m \
    src/Core/Client/Chats/TGClient+ChatsSupport.mm \
    src/Core/Client/Chats/TGClient+Chats.mm \
    src/Core/Client/Chats/TGClient+ChatMembers.mm \
    src/Core/Client/Chats/TGClient+ChatContacts.mm \
    src/Core/Client/Chats/TGClient+ChatReporting.mm \
    src/Core/Client/Chats/TGClient+Recents.mm \
    src/Core/Client/Chats/TGClient+ChatSearch.mm \
    src/Core/Client/Chats/TGClient+ChatFolders.mm \
    src/Core/Client/TGClient+ChatTools.m \
    src/Core/Stores/TGMessageStreamStore.mm \
    src/Core/Stores/TGMessageStore.m \
    src/Core/Stores/TGMessageStore+History.m \
    src/Core/Stores/TGSendStore.mm \
    src/Core/Support/TGUpdateBatcher.mm \
    src/Core/Client/Messages/TGClient+MessagesUpload.m \
    src/Core/Client/Messages/TGClient+Messages.m \
    src/Core/Client/Messages/TGClient+MessageRecord.m \
    src/Core/Client/Messages/TGClient+InlineMessages.m \
    src/Core/Model/TGMessageFlatten.m \
    src/Core/Model/TGServiceMessageText.m \
    src/Core/Model/TGMessageContentCommerce.m \
    src/Core/Model/TGMessageContentInteractive.m \
    src/Core/Model/TGMessageCard.m \
    src/Core/Model/TGLiveLocation.m \
    src/Core/Model/TGComposerText.m \
    src/Core/Model/TGGiftFlatten.m \
    src/Core/Model/TGPinnedLine.m \
    src/Core/Client/TGClient+MessageMeta.m \
    src/Core/Client/TGClient+SavedMessages.m \
    src/Core/Client/TGClient+Notifications.m \
    src/Core/Client/TGClient+Stickers.m \
    src/Core/Client/TGClient+Updates.m \
    src/Core/Stores/TGUpdateStore.m \
    src/Core/Client/TGClient+Files.mm \
    src/Core/Stores/TGStickerPack.mm \
    $(SRC)/Media/TGStickerImage.m \
    src/Core/Model/TGStatusText.m \
    src/Core/Client/TGClient+Proxy.m \
    src/Core/Client/TGClient+Groups.m \
    src/Core/Client/TGClient+GroupCalls.m \
    src/Core/Client/TGClient+Usernames.m \
    src/Core/Client/TGClient+Payments.m \
    src/Core/Client/TGClient+Calls.m \
    src/Core/Client/TGClient+Websites.m \
    src/Core/Client/TGClient+BotTools.m \
    src/Core/Client/TGClient+BotSession.m \
    src/Core/Client/TGClient+Affiliate.m \
    src/Core/Client/TGClient+GameScores.m \
    src/Core/Client/TGClient+Support.m \
    src/Core/Client/TGClient+TestHarness.m \
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
    src/Core/Platform/TGDevice.m \
    src/Core/Platform/TGCapabilities.m \
    src/Features/Contacts/TGContactSort.m \
    src/Features/Groups/Core/TGGroupLogic.m \
    src/Core/Platform/TGGhostMode.m \
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
    src/Core/Client/TGClient+Downloads.m \
    src/Core/Client/TGClient+Secret.m \
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
    src/Core/Client/TGClient+Auth.m \
    src/Core/Style/TGThemeFile.m \
    src/Core/Stores/TGChatThemeStore.m \
    src/Core/Stores/TGImageLruCache.mm \
    src/Core/Stores/TGPeerStore.m \
    src/Core/Stores/TGChatListStore.m \
    src/Core/Stores/TGMediaStore.m \
    src/Core/Stores/TGProfileStore.m \
    src/Core/Stores/TGProfileStore+Profile.m \
    src/Core/Stores/TGProfileStore+EmojiStatus.m \
    src/Core/Stores/TGProfileStore+ProfileAudio.m \
    src/Core/Stores/TGProfileStore+AccountProfileMedia.m \
    src/Core/Stores/TGSearchStore.m \
    src/Core/Stores/TGStickerBudget.m \
    src/Core/Platform/TGPerf.m \
    src/UI/Format/TGUIFormat.m \
    src/UI/Rows/TGRows.m \
    src/UI/Controllers/TGRowsDataSource.m \
    src/Features/Calls/TGGroupCallParticipantCell.m \
    src/Features/Chat/Views/TGMessageLayout.mm \
    src/UI/Messages/TGMessageCellKind.m \
    src/Features/Chat/TGPollPresentation.m \
    src/Features/Chat/Core/TGChatParityModel.m \
    src/Features/Chat/Core/TGChatActionMenuModel.m \
    src/Features/Chat/TGChecklistPresentation.m \
    src/Features/ChatList/TGChatListRowGeometry.m \
    src/Features/Media/TGMediaVeilBlur.m \
    src/Core/Stores/TGPlaybackQueue.m \
    src/Core/Model/TGProfileTabs.m \
    src/Core/Platform/TGPasscode.m

# Test helper ObjC sources. TGClientStub and TGCallAudioEngineStub stand in
# for the iOS-only production classes that TGCall.mm would otherwise need.
# UIKitShim.m backs tests/shim/UIKit so real src that imports UIKit
# (TGMessageLayout, TGClientInternal) compiles on the host.
TEST_HELPER_SRCS := \
    $(TESTS)/TGCallPeer.m \
    $(TESTS)/TGCallReflectorStub.m \
    $(TESTS)/TGClientStub.m \
    $(TESTS)/TGCallAudioEngineStub.m \
    $(TESTS)/TGAudioSessionShim.m \
    $(TESTS)/TGLibTgvoipBridge.mm \
    $(TESTS)/shim/UIKit/UIKitShim.m

# Stand-ins around the real TGClient for the second binary (see
# TGClientTestSupport.m).
CLIENT_HELPER_SRCS := \
    $(TESTS)/shim/UIKit/UIKitShim.m \
    $(TESTS)/TGClientTestSupport.m

# Test files (included via main.m / main_client.m, not compiled separately)
TEST_SRCS := \
    $(TESTS)/TGCallCryptoTests.m \
    $(TESTS)/TGCallStunTests.m \
    $(TESTS)/TGCallMessagesTests.m \
    $(TESTS)/TGCallIceTests.m \
    $(TESTS)/TGCallReflectorTests.m \
    $(TESTS)/TGCallV2Tests.m \
    $(TESTS)/TGCallIntegrationTests.m \
    $(TESTS)/TGCallVideoTests.m \
    $(TESTS)/TGLibTgvoipHooksTests.m \
    $(TESTS)/TGMessageLayoutTests.m \
    $(TESTS)/TGMessageCardLayoutTests.m \
    $(TESTS)/TGSoftVideoClockTests.m

CLIENT_TEST_SRCS := \
    $(TESTS)/TGJsonTests.m \
    $(TESTS)/TGUpdateFilterTests.m \
    $(TESTS)/TGClientChatsTests.m \
    $(TESTS)/TGClientFilesTests.m \
    $(TESTS)/TGStatusTextTests.m \
    $(TESTS)/TGClientDraftsTests.m \
    $(TESTS)/TGClientReceiveLoopTests.m \
    $(TESTS)/TGPlaybackQueueTests.m \
    $(TESTS)/TGClientVideoNoteSendTests.m \
    $(TESTS)/TGUpdatesCatchUpTests.m \
    $(TESTS)/TGClientAccountSlotsTests.m \
    $(TESTS)/TGClientFoldersTests.m \
    $(TESTS)/TGClientGroupsTests.m \
    $(TESTS)/TGClientMessagesFunctionsTests.m \
    $(TESTS)/TGClientRecordOnceTests.m \
    $(TESTS)/TGMessageParserTests.m \
    $(TESTS)/TGServiceMessageTextTests.m \
    $(TESTS)/TGMessagePreviewTests.m \
    $(TESTS)/TGMessageContentCommerceTests.m \
    $(TESTS)/TGMessageContentInteractiveTests.m \
    $(TESTS)/TGMessageCardTests.m \
    $(TESTS)/TGLiveLocationTests.m \
    $(TESTS)/TGComposerTextTests.m \
    $(TESTS)/TGGiftFlattenTests.m \
    $(TESTS)/TGPinnedLineTests.m \
    $(TESTS)/TGPollPresentationTests.m \
    $(TESTS)/TGParityChatTests.m \
    $(TESTS)/TGChecklistPresentationTests.m \
    $(TESTS)/TGLocalizationTests.m \
    $(TESTS)/TGMediaVeilBlurTests.m \
    $(TESTS)/TGClientAccountTests.m \
    $(TESTS)/TGClientProfileTests.m \
    $(TESTS)/TGProfileInfoRowsTests.m \
    $(TESTS)/TGProfileRowsTests.m \
    $(TESTS)/TGClientComposeTests.m \
    $(TESTS)/TGClientBareTests.m \
    $(TESTS)/TGClientAuthFunctionsTests.m \
    $(TESTS)/TGClientStickerAuthoringTests.m \
    $(TESTS)/TGClientFileToolsTests.m \
    $(TESTS)/TGClientAutosaveContactsTests.m \
    $(TESTS)/TGClientThreadsTests.m \
    $(TESTS)/TGClientChatToolsTests.m \
    $(TESTS)/TGClientTier2CommunitiesTests.m \
    $(TESTS)/TGClientSearchLanguageTests.m \
    $(TESTS)/TGClientUsernamesTests.m \
    $(TESTS)/TGClientEmojiReactionsTests.m \
    $(TESTS)/TGClientAppearanceDiagnosticsTests.m \
    $(TESTS)/TGClientMiscTests.m \
    $(TESTS)/TGClientStoriesTests.m \
    $(TESTS)/TGClientTier2Tests.m \
    $(TESTS)/TGClientTier3AuditTests.m \
    $(TESTS)/TGClientTier3BotsTests.m \
    $(TESTS)/TGClientGroupCallsTests.m \
    $(TESTS)/TGClientBusinessTests.m \
    $(TESTS)/TGClientNotificationsForumTests.m \
    $(TESTS)/TGThemeFileTests.m \
    $(TESTS)/TGPatternTests.m \
    $(TESTS)/TGUpdatesTests.mm \
    $(TESTS)/TGP1MigrationTests.mm \
    $(TESTS)/TGStickerBudgetTests.m \
    $(TESTS)/TGStickerImageTests.m \
    $(TESTS)/TGChatListRowGeometryTests.m \
    $(TESTS)/TGChatListRowsTests.m \
    $(TESTS)/TGChatListStoreTests.m \
    $(TESTS)/TGSearchStoreTests.m \
    $(TESTS)/TGProfileStoreTests.m \
    $(TESTS)/TGUpdateStoreTests.m \
    $(TESTS)/TGSendStoreTests.m \
    $(TESTS)/TGMessageStoreTests.m \
    $(TESTS)/TGPeerStoreTests.m \
    $(TESTS)/TGParitySettingsTests.m \
    $(TESTS)/TGSettingsPageModelsTests.m \
    $(TESTS)/TGSVGPathTests.m \
    $(TESTS)/TGIconCatalogTests.m \
    $(TESTS)/TGUIFormatTests.m \
    $(TESTS)/TGCustomEmojiStoreTests.m \
    $(TESTS)/TGParityRestTests.m \
    $(TESTS)/TGParityPeopleTests.m \
    $(TESTS)/TGRowModelTests.m \
    $(TESTS)/TGPeerRowTests.m \
    $(TESTS)/TGBlockedSendersTests.m \
    $(TESTS)/TGSettingsPageRowsTests.m \
    $(TESTS)/TGListRowsTests.m \
    $(TESTS)/TGCallRowsTests.m \
    $(TESTS)/TGGridRowTests.m \
    $(TESTS)/TGFieldRowTests.m \
    $(TESTS)/TGSettingsProfileGroupRowsTests.m \
    $(TESTS)/TGAccountPrivacyRowsTests.m \
    $(TESTS)/TGChatToolsStickerRowsTests.m \
    $(TESTS)/TGBotsChatMediaRowsTests.m \
    $(TESTS)/TGMessageCellFactoryTests.m

TEST_BINARY := $(BUILD)/TGCallTests
CLIENT_BINARY := $(BUILD)/TGClientTests
SIM_BINARY := $(BUILD)/call_sim
OFFICIAL_SIM_BINARY := $(BUILD)/official_tgvoip_sim

OPUS := $(shell pkg-config --variable=prefix opus 2>/dev/null || echo /opt/homebrew/opt/opus)

LIBTGVOIP_SRCS := \
    $(ROOT)/third_party/libtgvoip/BlockingQueue.cpp \
    $(ROOT)/third_party/libtgvoip/Buffers.cpp \
    $(ROOT)/third_party/libtgvoip/CongestionControl.cpp \
    $(ROOT)/third_party/libtgvoip/EchoCanceller.cpp \
    $(ROOT)/third_party/libtgvoip/JitterBuffer.cpp \
    $(ROOT)/third_party/libtgvoip/MediaStreamItf.cpp \
    $(ROOT)/third_party/libtgvoip/MessageThread.cpp \
    $(ROOT)/third_party/libtgvoip/NetworkSocket.cpp \
    $(ROOT)/third_party/libtgvoip/OpusDecoder.cpp \
    $(ROOT)/third_party/libtgvoip/OpusEncoder.cpp \
    $(ROOT)/third_party/libtgvoip/PacketReassembler.cpp \
    $(ROOT)/third_party/libtgvoip/VoIPController.cpp \
    $(ROOT)/third_party/libtgvoip/VoIPServerConfig.cpp \
    $(ROOT)/third_party/libtgvoip/json11.cpp \
    $(ROOT)/third_party/libtgvoip/logging.cpp \
    $(ROOT)/third_party/libtgvoip/audio/AudioIO.cpp \
    $(ROOT)/third_party/libtgvoip/audio/AudioInput.cpp \
    $(ROOT)/third_party/libtgvoip/audio/AudioOutput.cpp \
    $(ROOT)/third_party/libtgvoip/audio/AudioIOCallback.cpp \
    $(ROOT)/third_party/libtgvoip/audio/Resampler.cpp \
    $(ROOT)/third_party/libtgvoip/os/posix/NetworkSocketPosix.cpp \
    $(ROOT)/third_party/libtgvoip/os/darwin/DarwinSpecific.mm \
    $(ROOT)/third_party/libtgvoip/video/ScreamCongestionController.cpp \
    $(ROOT)/third_party/libtgvoip/tests/MockReflector.cpp

# ─── targets ──────────────────────────────────────────────────────────────────

.PHONY: test build clean tokens sizes screens sim official_sim icons client

icons:
	@echo "\n════════ Icon catalogue lint ════════"
	@sh $(ROOT)/scripts/lint_icons.sh

client:
	@echo "\n════════ Client import lint ════════"
	@chmod +x $(ROOT)/scripts/lint_client.sh
	@sh $(ROOT)/scripts/lint_client.sh

screens:
	@echo "\n════════ Screen ownership lint ════════"
	@chmod +x $(ROOT)/scripts/lint_screens.sh
	@sh $(ROOT)/scripts/lint_screens.sh

# The design-token lint. Cheap, so it runs first: a literal size or colour
# fails the suite the same way a broken assertion does.
tokens:
	@echo "\n════════ Design token lint ════════"
	@sh $(ROOT)/scripts/lint_tokens.sh

sizes:
	@echo "\n════════ File size lint ════════"
	@sh $(ROOT)/scripts/lint_size.sh

TEST_BINARY_DEPS := $(TESTS)/main.m $(C_SRCS) $(OBJC_SRCS) $(TEST_HELPER_SRCS) $(TEST_SRCS) \
                $(TESTS)/TGTestRunner.h $(TESTS)/TGCallTestHelpers.h
CLIENT_BINARY_DEPS := $(TESTS)/main_client.mm $(CLIENT_OBJC_SRCS) $(CLIENT_HELPER_SRCS) \
                $(CLIENT_TEST_SRCS) $(TESTS)/TGTestRunner.h
SIM_BINARY_DEPS := $(TESTS)/call_sim.mm $(C_SRCS) $(OBJC_SRCS) $(TEST_HELPER_SRCS) \
                $(TESTS)/TGCallTestHelpers.h
OFFICIAL_SIM_DEPS := $(TESTS)/official_tgvoip_sim.mm $(LIBTGVOIP_SRCS)

test: tokens sizes screens $(TEST_BINARY) $(CLIENT_BINARY)
	@echo "\n════════ Running call stack tests ════════"
	$(TEST_BINARY)
	@echo "\n════════ Running TGClient regression tests ════════"
	$(CLIENT_BINARY)

sim: $(SIM_BINARY)
	@echo "\n════════ Running VoIP call simulation (LegacyTG stack) ════════"
	$(SIM_BINARY)

bench: $(BUILD)/call_bench

official_sim: $(OFFICIAL_SIM_BINARY)
	@echo "\n════════ Running VoIP call simulation (Official libtgvoip) ════════"
	$(OFFICIAL_SIM_BINARY)

build: $(TEST_BINARY) $(CLIENT_BINARY) $(SIM_BINARY) $(OFFICIAL_SIM_BINARY)

# One object per source, with header dependencies: a change rebuilds the
# files it touches and relinks, instead of recompiling ~120 sources in one
# clang call every time. Both binaries share objects (same CFLAGS); run with
# -j to compile them in parallel.
OBJDIR := $(BUILD)/obj
objs_of = $(patsubst /%,$(OBJDIR)/%.o,$(abspath $(1)))
TEST_OBJS   := $(call objs_of,$(C_SRCS) $(OBJC_SRCS) $(TEST_HELPER_SRCS) $(TESTS)/main.m)
CLIENT_OBJS := $(call objs_of,$(CLIENT_OBJC_SRCS) $(CLIENT_HELPER_SRCS) $(TESTS)/main_client.mm)

# No ccache here: in depend mode with -fmodules it served a stale
# main_client object after a test file #imported into it changed (five new
# tests never ran). make's own -MMD dependencies already rebuild only what
# changed.

$(OBJDIR)/%.o: /%
	@mkdir -p $(dir $@)
	@$(CLANG) $(CFLAGS) -MMD -MP -c /$* -o $@

-include $(TEST_OBJS:.o=.d) $(CLIENT_OBJS:.o=.d)

$(TEST_BINARY): $(TEST_OBJS)
	@mkdir -p $(BUILD)
	$(CLANG) $(CFLAGS) $(TEST_OBJS) $(LDFLAGS) -o $@
	@echo "  Built $(notdir $@)"

$(CLIENT_BINARY): $(CLIENT_OBJS)
	@mkdir -p $(BUILD)
	$(CLANG) $(CFLAGS) $(CLIENT_OBJS) $(LDFLAGS) -o $@
	@echo "  Built $(notdir $@)"

$(SIM_BINARY): $(SIM_BINARY_DEPS)
	@mkdir -p $(BUILD)
	$(CLANG) $(CFLAGS) \
	    $(C_SRCS) \
	    $(OBJC_SRCS) \
	    $(TEST_HELPER_SRCS) \
	    $(TESTS)/call_sim.mm \
	    $(LDFLAGS) \
	    -o $@
	@echo "  Built $(notdir $@)"

$(BUILD)/call_bench: $(TESTS)/call_bench.mm $(C_SRCS) $(OBJC_SRCS) $(TEST_HELPER_SRCS)
	@mkdir -p $(BUILD)
	$(CLANG) $(CFLAGS) -I$(OPUS)/include/opus \
	    $(C_SRCS) \
	    $(OBJC_SRCS) \
	    $(TEST_HELPER_SRCS) \
	    $(TESTS)/call_bench.mm \
	    $(LDFLAGS) -L$(OPUS)/lib -lopus \
	    -o $@

$(OFFICIAL_SIM_BINARY): $(OFFICIAL_SIM_DEPS)
	@mkdir -p $(BUILD)
	$(CLANG) -std=c++14 \
	    -arch $(ARCH) \
	    $(if $(SDK),-isysroot $(SDK),) \
	    -DTGVOIP_USE_CALLBACK_AUDIO_IO \
	    -DTGVOIP_NO_DSP \
	    -DTGVOIP_NO_AEC \
	    -DWEBRTC_POSIX \
	    -I$(ROOT)/third_party/libtgvoip \
	    -I$(OPENSSL)/include \
	    -I$(OPUS)/include \
	    -I$(OPUS)/include/opus \
	    -L$(OPENSSL)/lib \
	    -L$(OPUS)/lib \
	    -lcrypto -lssl -lopus \
	    -lc++ \
	    -framework Foundation \
	    -framework CoreAudio \
	    -framework AudioToolbox \
	    $(LIBTGVOIP_SRCS) \
	    $(TESTS)/official_tgvoip_sim.mm \
	    -o $@
	@echo "  Built $(notdir $@)"

clean:
	@rm -rf $(BUILD)
	@echo "  Cleaned $(BUILD)"
