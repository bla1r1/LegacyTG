#import "TGClient+Base.h"

@interface TGClient (StoriesAlbums)

/// "id", "name", "photoFileId" and "videoFileId" per album.
/// Telegram returns only the album record (id, name, icons) - the stories it
/// now holds are read with -storiesInAlbum:... after this answers.
/// Flattened stories in an album, in the album's order.
/// Moves the named stories to the front of the album in the order given.
@end
