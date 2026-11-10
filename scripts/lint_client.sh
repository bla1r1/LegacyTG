#!/bin/sh
# lint_client.sh - fail when a Feature or UI file reaches around the stores.
#
# Views talk to the domain stores in src/Core/Stores, never to TGClient or one
# of its duty headers. The allow list is the migration queue: one current
# importer per line. Remove a line when that screen moves; never add one.
set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT" || exit 1

ALLOW="
src/Features/Auth/TGLoginViewController+Phone.m
src/Features/Auth/TGLoginViewController+Steps.m
src/Features/Auth/TGLoginViewController.m
src/Features/Auth/TGQRViewController.m
src/Features/BotsPayments/TGAffiliateProgramsViewController.m
src/Features/BotsPayments/TGGiftViewController.m
src/Features/BotsPayments/TGSponsoredMessagesViewController.m
src/Features/BotsPayments/TGStarsGiftsViewController.m
src/Features/Business/Pages/TGBusinessAwayViewController.m
src/Features/Business/Pages/TGBusinessChatLinksViewController.m
src/Features/Business/Pages/TGBusinessGreetingViewController.m
src/Features/Business/Pages/TGBusinessHoursViewController.m
src/Features/Business/Pages/TGBusinessIntroViewController.m
src/Features/Business/Pages/TGBusinessLocationViewController.m
src/Features/Business/Pages/TGBusinessProfileViewController.m
src/Features/Business/TGBusinessMessagesViewController.m
src/Features/Business/TGBusinessViewControllerSupport.m
src/Features/Calls/TGCallMessagesViewController.m
src/Features/Calls/TGCallViewController.m
src/Features/Calls/TGGroupCallParticipantsViewController.m
src/Features/Calls/TGGroupCallViewController.m
src/Features/Calls/TGVideoChatSetupViewController.m
src/Features/Calls/TGVideoChatStreamViewController.m
src/Features/Calls/Views/TGCallMiniBar.m
src/Features/Channels/TGSimilarChannelsViewController.m
src/Features/ChatList/TGChatListViewControllerInternal.h
src/Features/ChatList/TGSearchViewController.m
src/Features/Contacts/TGCloseFriendsViewController.m
src/Features/Contacts/TGContactsViewController.m
src/Features/Contacts/TGNewContactViewController.m
src/Features/Dev/TGDevBotConsoleViewController.m
src/Features/Dev/TGDevEnvironmentViewController.m
src/Features/Dev/TGDevFileToolsViewController.m
src/Features/Dev/TGDevHubViewController.m
src/Features/Dev/TGDevShowcase.m
src/Features/Dev/TGDevTestHarnessViewController.m
src/Features/Dev/TGDevWebProxyCarrierViewController.m
src/Features/Groups/Core/TGGroupActions.m
src/Features/Groups/Core/TGGroupBase.m
src/Features/Groups/Core/TGGroupData.m
src/Features/Groups/Core/TGGroupIdentity.m
src/Features/Groups/Core/TGGroupInvites.m
src/Features/Groups/Core/TGGroupMembers.m
src/Features/Groups/Core/TGGroupPermissions.m
src/Features/Groups/Core/TGGroupSections.m
src/Features/Groups/Core/TGGroupSwitches.m
src/Features/Groups/Core/TGGroupTools.m
src/Features/Groups/Core/TGGroupUsernames.m
src/Features/Groups/TGAdminRightsViewController.m
src/Features/Groups/TGAntiSpamViewController.m
src/Features/Groups/TGCommunitiesViewController.m
src/Features/Groups/TGCommunityViewController.m
src/Features/Groups/TGGroupMemberActions.m
src/Features/Groups/TGMemberListViewController.m
src/Features/Groups/TGTopicsViewController.m
src/Features/Groups/Views/TGGroupSwitch.m
src/Features/Media/Core/TGMediaViewerBase.m
src/Features/Media/Core/TGMediaViewerChrome.m
src/Features/Media/Core/TGMediaViewerMoreSheet.m
src/Features/Media/Core/TGMediaViewerPages.m
src/Features/Media/Core/TGMediaViewerPresenting.m
src/Features/Media/Core/TGMediaViewerProgress.m
src/Features/Media/Core/TGMediaViewerSaving.m
src/Features/Media/Core/TGMediaViewerTransitions.m
src/Features/Media/Core/TGMediaViewerVideo.m
src/Features/Media/TGFileInfoViewController.m
src/Features/Media/TGStickerEditorViewController.m
src/Features/Media/TGStickerPacksViewController.m
src/Features/Profile/TGEditProfileViewController.m
src/Features/Profile/TGEmojiStatusViewController.m
src/Features/Profile/TGProfileAppearanceViewController.m
src/Features/Profile/TGProfileAudioViewController.m
src/Features/Profile/TGProfileBirthdaySuggestViewController.m
src/Features/Profile/TGProfilePhotosViewController.m
src/Features/Profile/TGProfileViewControllerInternal.h
src/Features/Settings/TGActiveNotificationsViewController.m
src/Features/Settings/TGDeviceViewController.m
src/Features/Settings/TGNetworkViewController.m
src/Features/Settings/TGNotificationCategoryViewController.m
src/Features/Settings/TGPrivacyRuleViewController.m
src/Features/Settings/TGSessionsViewController.m
src/Features/Settings/TGSettingsViewController.m
src/Features/Settings/TGSettingsViewControllerInternal.h
src/Features/Settings/TGStorageViewController.m
src/Features/Settings/TGSupportInfoViewController.m
src/Features/Settings/TGTextStylesViewController.m
src/Features/Settings/TGUserPickerViewController.m
src/Features/Settings/TGUsernameSettingsViewController.m
src/Features/Settings/TGWebsitesViewController.m
src/Features/Stories/TGLiveStoryViewController.m
src/Features/Stories/TGPublicStoriesViewController.m
src/Features/Stories/TGStoriesMenuViewController.m
src/Features/Stories/TGStoryAlbumsViewController.m
src/Features/Stories/TGStoryArchiveViewController.m
src/Features/Stories/TGStoryComposerViewController.m
src/Features/Stories/TGStoryInfoViewController.m
src/Features/Stories/TGStorySettingsViewController.m
src/Features/Stories/TGStoryViewerViewController.m
"

allowed() {
	printf '%s\n' "$ALLOW" | grep -qx "$1"
}

hits=$(grep -rnE \
	'#import[[:space:]]+"(TGClient\.h|TGClient\+[^"]*\.h)"' \
	src/Features src/UI --include='*.m' --include='*.mm' --include='*.h' \
	| grep -vE ':[[:space:]]*(//|\*|/\*)' || true)

status=0
if [ -n "$hits" ]; then
	while IFS= read -r hit; do
		file=${hit%%:*}
		allowed "$file" && continue
		printf '%s\n' "$hit"
		status=1
	done <<EOF
$hits
EOF
fi

# The list only shrinks: a migrated file still listed is an error too.
for file in $ALLOW; do
	printf '%s\n' "$hits" | grep -q "^$file:" && continue
	echo "$file: migrated, remove it from the allow list"
	status=1
done

if [ "$status" -eq 0 ]; then
	echo "  client: clean (screens use the stores, remaining importers are listed)"
else
	printf '\n  A Feature or UI file imports TGClient directly:\n'
	printf '  %s\n\n' "ask the domain store in src/Core/Stores for what the screen needs"
fi
exit "$status"
