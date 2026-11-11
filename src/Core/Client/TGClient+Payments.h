//
// TGClient+Payments.h - saved order info, a card lookup, a suggested post's
// offer and the validation step a checkout runs before it charges anything.
//
// None of these puts money on a card: the saved order is the address and
// phone Telegram kept from an earlier checkout, the card lookup reads the
// provider's title and links for a number, validateOrderInfo asks Telegram
// what shipping exists for a basket, and addOffer is the price line a channel
// direct-messages post carries. A user account sends all of them; Telegram
// decides which of its endpoints answer, and the screen shows that answer.
//
#import "TGClient+Base.h"

@interface TGClient (Payments)

/// The order Telegram saved from the last checkout. Nil with `error` set
/// when there is nothing saved - TDLib answers 404 for "none" - or when the
/// account may not read it.
/// Forgets the saved order. The next checkout asks for the fields again.
/// What the provider knows about a card number: its title, and the links its
/// own page opens (3-D Secure, support, the issuer). The number is not kept.
/// Puts a price on a suggested post. `starCount` is the whole price in
/// Telegram Stars; `sendDate` is when it should be published, 0 for now.
/// TDLib only accepts it on a message whose properties say an offer can be
/// added, so a user account usually sees the server's refusal instead.
/// Checks an order against a named invoice and returns the order-info id the
/// payment form needs, plus every shipping option Telegram offers. `order`
/// carries the checkout fields; missing ones are sent as empty strings
/// because orderInfo has no optional members.
@end
