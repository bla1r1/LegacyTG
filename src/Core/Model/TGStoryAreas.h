//
// TGStoryAreas.h - the tappable areas a story carries (story.areas): where
// each sits on the picture and what a tap on it does.
//
// Official draws a highlight for some and a widget for others
// (StoryItemSetContainerComponent); on the A4 the highlight goes and the tap
// stays where official puts it.
//
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

/// Each TDLib storyArea as @{x, y (centre), w, h (fractions of the picture),
/// rotation (degrees), kind, ...}: "link" url, "message" chatId messageId.
/// Areas with nothing to do on a tap here are left out.
FOUNDATION_EXPORT NSArray *TGStoryAreasFromTD(NSArray *areas);

/// The area under `point` in a picture drawn at `picture`, or nil. A later
/// area lies over an earlier one, as in the story's own stacking.
FOUNDATION_EXPORT NSDictionary *TGStoryAreaAt(NSArray *areas, CGPoint point, CGRect picture);

/// A chat page's stories with the pinned ones first, in pinned_story_ids
/// order, each marked "isPinned" (official shows pinned stories first on a
/// profile's stories pane). `stories` are flattened, keyed "storyId".
FOUNDATION_EXPORT NSArray *TGStoriesPinnedFirst(NSArray *stories, NSArray *pinnedIds);
