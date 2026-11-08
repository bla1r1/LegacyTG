#import "TGClient+Base.h"

// C helpers shared by the feature categories.
NSDictionary *TGFeatureDict(id value);
NSArray *TGFeatureArray(id value);
NSString *TGFeatureString(id value);
NSString *TGFeatureErrorText(NSDictionary *result);
BOOL TGFeatureOK(NSDictionary *result);
NSString *TGFeatureFormattedTextValue(id value);
NSNumber *TGFeaturePhotoFileId(id photo);
NSString *TGFeatureCommunityStatus(NSDictionary *status);
NSString *TGFeatureChatTitle(int64_t chatId);
NSArray *TGFeatureMessagesFromResult(NSDictionary *result);
NSString *TGFeatureSuggestedState(NSString *type);
NSString *TGFeatureSuggestedPrice(NSDictionary *price);
NSString *TGFeatureActionKey(NSDictionary *action);
NSString *TGFeatureActionTitle(NSDictionary *action);
NSString *TGFeatureRichTextPlain(id value);
void TGFeatureFlattenBlocks(NSArray *blocks, NSMutableArray *lines);
NSString *TGFeaturePageBlockText(NSDictionary *block);

@interface TGClient (FeatureSupport)

#pragma mark - shared shapes

/// An inputRichMessage with one paragraph per line, so a plain string can
/// reach every rich-message request.
+ (NSDictionary *)inputRichMessageWithText:(NSString *)text;

/// The readable text of a RichMessage: paragraphs, headings, lists, quotes
/// and captions, joined by newlines. Empty for a message this client cannot
/// read.
+ (NSString *)plainTextFromRichMessage:(NSDictionary *)richMessage;

/// inputChecklist with `tasks` (each "id" and "text") and the two
/// "others can" flags. Shared by the editor and the send path.
+ (NSDictionary *)inputChecklistWithTitle:(NSString *)title
                                    tasks:(NSArray *)tasks
                              othersCanAdd:(BOOL)othersCanAdd
                             othersCanMark:(BOOL)othersCanMark;


@end
