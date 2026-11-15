//
// TGMessageMetrics.h - what a message row measures before any view exists:
// its stamp, its quote, its decorations, a poll's and a checklist's height,
// the service line. Inputs are the message dictionary and what the caller
// already holds (the replied message, the loaded messages, the pending
// votes); nothing here reads the chat screen, so the host suite runs it.
//
#ifndef TGMESSAGEMETRICS_H
#define TGMESSAGEMETRICS_H

#import "TGMessageLayout.h"
#import "TGStyle.h"

#ifdef __cplusplus
extern "C" {
#endif

/// The gap between the last word of a message and the stamp on its line.
static const CGFloat kStampGap        = TGMetricPad;
/// A quote block: the author's line, then what they said, then a gap.
static const CGFloat kQuoteLine       = TGMetricLineSubhead;
static const CGFloat kQuoteBlock      = TGMetricLineSubhead + TGMetricLineSubhead + TGMetricPadSmall;
/// The stripe down the left of a quote block, and the text's indent past it.
static const CGFloat kQuoteBarWidth   = TGMetricPadTiny;
static const CGFloat kQuoteTextInset  = TGMetricPad;
/// A service plate - a day, or an event like "pinned a message" - sits on a
/// row of its own: a gap, one line of header type, the same gap again.
static const CGFloat kServiceGap      = TGMetricPad;
static const CGFloat kServiceEventGap = TGMetricPadSmall;
static const CGFloat kServicePlate    = TGMetricLineHeader;
static const CGFloat kServiceRow      = TGMetricPad + TGMetricLineHeader + TGMetricPad;
static const CGFloat kServiceEventRow = TGMetricPadSmall + TGMetricLineHeader + TGMetricPadSmall;
/// Text from the end of a service plate, and the margin the plate keeps from
/// the sides of the table so a long day never runs edge to edge.
static const CGFloat kServicePlatePad    = TGMetricPadMedium;
static const CGFloat kServicePlateMargin = TGMetricPadWide + TGMetricPadMedium;
/// The unread marker, which is a band across the table rather than a plate.
static const CGFloat kUnreadBar       = TGMetricLineBody + TGMetricPadSmall;
/// A call bubble: a glyph beside two lines, at a height that does not vary.
static const CGFloat kCallBubble      = TGMetricButtonHeight;
/// What a call bubble keeps beside its text for the glyph and the button, and
/// the least width it will shrink to so a short "Missed call" is still a card.
static const CGFloat kCallBubbleRoom  = 80.0f;
static const CGFloat kCallBubbleMin   = 190.0f;
/// A document bubble, wide enough for a file name beside its tile.
static const CGFloat kDocBubble       = 225.0f;
/// A contact bubble: a disc, a name and a number, with a call button under.
static const CGFloat kContactBubble   = 230.0f;
/// The person row, a line for the stamp, then Call and Add. The stamp sat in
/// the button row, on "Add", until it got its own line.
static const CGFloat kContactBubbleH  = TGMetricPersonRow + TGMetricLineMicro + TGMetricButtonHeightSmall;
/// A location bubble: the map card, with a caption strip beneath it.
static const CGFloat kLocationBubble  = 224.0f;
static const CGFloat kLocationBubbleH = TGMetricMapCardHeight + TGMetricRow;
/// A round video message, and an animated sticker. Both square; the round
/// note reads its side from the token so the bubble and the full-screen
/// player cannot drift apart by two points again.
static const CGFloat kRoundSide       = TGMetricRoundVideoSide;
static const CGFloat kLottieSide      = 128.0f;
/// The narrowest a text bubble will be, so one word is still a bubble.
static const CGFloat kBubbleMinW      = 170.0f;
/// A bubble that carries a picture is this wide whatever the picture is.
static const CGFloat kPicBubbleW      = 190.0f;
/// The shortest a bubble row gets, so a one-word message still reads as a
/// row and not as a line of text in a list.
static const CGFloat kBubbleRowMin    = TGMetricRow - TGMetricPadSmall;
/// How far a stamp on a picture sits in from its corner.
static const CGFloat kMediaStampInset = TGMetricPadSmall;
/// How far a photo or album sits from its bubble's edge.
static const CGFloat kMediaInset      = TGMetricPadTiny;
/// The comments footer under a channel post: its own row across the bubble,
/// under the text and the time, as tall as the contact card's button row.
static const CGFloat kCommentsBar     = TGMetricButtonHeightSmall;
/// A link preview's small picture, in the preview's top right corner.
static const CGFloat kLinkThumbSide   = 48.0f;
/// The eye glyph beside a channel post's view count.
static const CGFloat kStampEyeSide     = TGMetricStampHeight;
/// Nothing between the eye and the count: the glyph's own 2 pt margin is
/// the gap, which comes to official's 3 pt between icon and date.
static const CGFloat kStampEyePad      = TGMetricZero;
/// A poll row: the dot's column, then the option, then its share on the right,
/// over a track that runs the row's width.
static const CGFloat kPollTextColumn  = TGMetricPadLarge + TGMetricPad;
static const CGFloat kPollShareWidth  = 40.0f;
static const CGFloat kPollTrackDrop   = TGMetricPadSmall;
static const CGFloat kPollTrackHeight = TGMetricPadTiny;
/// The "N voted" line under a poll's question.
static const CGFloat kPollVotedLine   = TGMetricPadTiny + TGMetricLineRow;
/// A poll bubble's text stack: the description, then the kind line, then the
/// options. The same constants are read by the cell and by TGMessagePollHeight.
static const CGFloat kPollDescriptionGap = TGMetricPadTiny;
static const CGFloat kPollKindGap        = TGMetricPadTiny;
static const CGFloat kPollKindLine       = TGMetricLineCaption;
static const CGFloat kPollOptionsGap     = TGMetricPadSmall;
/// The "Vote" button under a multiple-answer poll's draft answers.
static const CGFloat kPollVoteHeight     = TGMetricButtonSmallH;
static const CGFloat kPollVoteGap        = TGMetricPadTiny;
/// A quiz's explanation under the options, and the votes line under it all.
static const CGFloat kPollExplanationGap = TGMetricPadSmall;
static const CGFloat kPollFooterGap      = TGMetricPadSmall;
static const CGFloat kPollFooterLine     = TGMetricLineCaption;
/// The room the stamp keeps below the votes line.
static const CGFloat kPollStampRoom      = TGMetricLineBody;
/// A checklist bubble: the title, one row per task, then the progress line.
/// The cell and TGMessageChecklistHeight read the same constants, so the rows and
/// the bubble cannot drift apart.
static const CGFloat kChecklistTitleGap    = TGMetricPadSmall;
static const CGFloat kChecklistRow         = TGMetricPollRow;
static const CGFloat kChecklistTextColumn  = TGMetricPadLarge + TGMetricPad;
static const CGFloat kChecklistProgressGap = TGMetricPadSmall;
static const CGFloat kChecklistProgressLine = TGMetricLineMicro;
static const CGFloat kChecklistStampRoom   = TGMetricLineBody;

/// One poll option's row: the text measured at `rowWidth`, plus the row's own
/// padding, and never under kPollRow. Layout and cell both call it, so the
/// height they place and the height they draw cannot drift.
FOUNDATION_EXPORT CGFloat TGPollOptionRowHeight(NSDictionary *option, CGFloat rowWidth);

/// "12:29", "12:29 edited", or with views "2.2M Name, 12:29": the line in the
/// corner of the bubble. The eye sits before the first word, so the count is it.
FOUNDATION_EXPORT NSString *TGMessageStampText(NSDictionary *m);

/// The stamp's width with the eye and the ticks it carries.
FOUNDATION_EXPORT CGFloat TGMessageStampWidth(NSDictionary *m);

/// Where the eye goes for a right-aligned stamp ending at `textRight`: its
/// own gap clear of the words themselves, not of the label's slack
/// (ChatMessageDateAndStatusNode puts the date 3 pt after the icon).
FOUNDATION_EXPORT CGFloat TGStampEyeX(CGFloat textRight, NSString *stampText);

/// Room the boost badge takes at the end of a group sender's name line:
/// the bolt alone for one boost, the bolt and the count for more, nothing
/// for none or an outgoing message (official shows it on incoming only).
FOUNDATION_EXPORT CGFloat TGMessageBoostBadgeWidth(NSDictionary *m);
FOUNDATION_EXPORT NSString *TGMessageBoostBadgeText(NSDictionary *m);

/// A link preview's picture in a text column `columnW` wide: the column's
/// width at the photo's proportions (no taller than kImageMax) when the
/// preview shows large media, the corner square otherwise, zero for none.
FOUNDATION_EXPORT CGSize TGLinkPreviewMediaSize(NSDictionary *m, CGFloat columnW);

/// The stamp's parts on one line, laid right to left from `right`: the ticks
/// of a sent message, the text, and the views eye just before the count.
/// `midY` is the line's centre. Every stamp (text line, document, the plate
/// on a picture) is placed by this, so the eye cannot drift off its count and
/// the text gets exactly the width it was measured at.
typedef struct {
	CGRect eye;      ///< empty without views
	CGRect text;
	CGRect ticks;    ///< empty for a message from someone else
	CGFloat width;   ///< from the eye (or the text) to `right`
} TGMessageStampParts;

FOUNDATION_EXPORT TGMessageStampParts TGMessageStampPlace(NSDictionary *m,
		CGFloat right, CGFloat midY);

/// The plate a stamp sits on over a picture: the parts with TGMetricPadSmall
/// round them, its right edge at `right`, its bottom at `bottom`.
FOUNDATION_EXPORT CGRect TGMessageStampPlate(NSDictionary *m, CGFloat right,
		CGFloat bottom, TGMessageStampParts *parts);

/// Telegram puts the stamp at the end of a one-line message when it fits
/// there, and on its own line only when it does not.
FOUNDATION_EXPORT BOOL TGMessageStampFitsInline(NSDictionary *m, CGFloat fontSize);

/// The quote block's text: TDLib's inline quote, else the replied message
/// described, else "..." while it loads. Nil for a message that answers nothing.
FOUNDATION_EXPORT NSString *TGMessageQuoteText(NSDictionary *m, NSDictionary *replied);

FOUNDATION_EXPORT NSArray *TGMessageQuoteEntities(NSDictionary *m, NSDictionary *replied);

/// Who wrote the replied message: "You", or `senderName`. Nil until the
/// original is loaded; TDLib's inline quote carries the text, not the author.
FOUNDATION_EXPORT NSString *TGMessageQuoteAuthor(NSDictionary *replied, NSString *senderName);

/// Forward line, quote block, comments bar and bot buttons over the body.
FOUNDATION_EXPORT CGFloat TGMessageDecorationHeight(NSDictionary *m, BOOL hasQuote);

/// "Leave a Comment", "1 Comment", "12 Comments".
FOUNDATION_EXPORT NSString *TGMessageCommentsTitle(NSInteger count);

/// Title, a row per task, the progress line.
FOUNDATION_EXPORT CGFloat TGMessageChecklistHeight(NSDictionary *m);

/// Question, description and kind line, one row per option, Vote for a
/// multiple-answer draft (`pendingVotes` non-empty), the quiz explanation and
/// the votes line.
FOUNDATION_EXPORT CGFloat TGMessagePollHeight(NSDictionary *m, NSIndexSet *pendingVotes);

/// The service line as drawn: who acted (`who`, nil for a separator), and for
/// a pin the quoted message once it is among `messages`.
FOUNDATION_EXPORT NSString *TGMessageServiceLine(NSDictionary *m, NSString *who,
		NSArray *messages);

#ifdef __cplusplus
}
#endif

#endif
