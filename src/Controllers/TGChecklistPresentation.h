//
// TGChecklistPresentation.h - what a checklist says about itself, apart from
// any view.
//
// These read the dictionary TGFlattenInteractiveContent builds, so the host
// suite can pin the wording and the done rule without a phone.
//
#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

/// "No tasks completed" / "1 of 3 completed" / "3 of 3 completed".
NSString *TGChecklistProgressLine(NSDictionary *checklist);

/// A task is done when TDLib names who completed it or when it carries a
/// completion date; either is enough, and older builds send only one.
BOOL TGChecklistTaskDone(NSDictionary *task);

/// Whether this account may tick and untick the checklist's tasks.
BOOL TGChecklistCanToggle(NSDictionary *checklist);

#ifdef __cplusplus
}
#endif
