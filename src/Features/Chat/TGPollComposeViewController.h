//
// TGPollComposeViewController.h - official's New Poll, opened as a modal
// form from the attach menu's Poll: the question and its description, the
// options (a new empty field appears as the last one is filled), the
// settings switches, and in Quiz Mode the right answer and an explanation.
//
#import "TGRowsViewController.h"

@interface TGPollComposeViewController : TGRowsViewController

/// A channel has no Show Who Voted or Allow Adding Options, as official.
- (instancetype)initWithChatId:(int64_t)chatId isChannel:(BOOL)isChannel;

@end
