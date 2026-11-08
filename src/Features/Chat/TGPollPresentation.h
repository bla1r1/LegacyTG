//
// TGPollPresentation.h - what a poll says about itself, apart from any view.
//
// These are pure functions over the poll dictionary that
// TGFlattenInteractiveContent builds. Keeping them here means the host suite
// can pin Telegram's wording and the chat only has to place the result.
//
#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef NS_ENUM(NSInteger, TGPollMark) {
	TGPollMarkNone = 0,
	TGPollMarkChosen,
	TGPollMarkCorrect,
	TGPollMarkWrong
};

/// The option's text. TDLib may hand a plain string or a formatted-text
/// object, so every reader goes through here.
NSString *TGPollOptionText(NSDictionary *option);

/// "Final results", "Anonymous Quiz", "Quiz", "Anonymous Poll" or "Poll".
NSString *TGPollKindLine(NSDictionary *poll);

/// "Nobody answered yet" / "N answered" for a quiz, votes for a poll.
NSString *TGPollVotesLine(NSDictionary *poll);

/// "ends in M:SS" / "ends in H:MM:SS" / "ends in N days"; nil when closed,
/// unscheduled or past.
NSString *TGPollClosesLine(NSDictionary *poll, NSTimeInterval now);

/// Closed polls show their tally, and so does any poll this account voted in.
BOOL TGPollShowsResults(NSDictionary *poll);

/// The mark an option wears once results are visible.
TGPollMark TGPollMarkForOption(NSDictionary *poll, NSUInteger index);

/// The draft answers of a multiple-answer poll, ascending.
NSArray *TGPollVoteIndexes(NSIndexSet *pending);

/// A poll whose own vote can be taken back.
BOOL TGPollCanRetract(NSDictionary *poll);

#ifdef __cplusplus
}
#endif
