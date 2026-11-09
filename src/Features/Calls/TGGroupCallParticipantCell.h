//
// TGGroupCallParticipantCell - one person in a group call, as row data.
//
// The call screen and the full participant list describe a person with the
// same TGPeerRow; the drawing is TGPeerRowCell's. This file is the shared
// description, not a cell: a screen hands the row to TGRowsDataSource and the
// table renders it.
//
#import <UIKit/UIKit.h>

#ifdef __cplusplus
extern "C" {
#endif

/// What the row says under the name. One line, in the order a person scans
/// it: mute, hand, video, screen, volume. Shared by both lists.
FOUNDATION_EXPORT NSString *TGGroupCallParticipantDetail(NSDictionary *participant);

/// The TGPeerRow for one participant. Speaking turns the subtitle to the
/// accent colour, the current user turns the name to it, and a muted row
/// carries `mutedIcon` (TGRowTrailingImage) so the state is a row key rather
/// than a second cell class.
FOUNDATION_EXPORT NSMutableDictionary *TGGroupCallParticipantRow(
		NSDictionary *participant, UIColor *accentColour, UIImage *mutedIcon);

#ifdef __cplusplus
}
#endif

// vim:ft=objc
