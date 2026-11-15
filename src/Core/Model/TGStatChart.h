//
// TGStatChart.h - a statistics graph from TDLib's chart JSON
// (statisticalGraphData.json_data), reduced to what a picture needs.
//
#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

/// {"x": [stamps], "series": [{"name", "colour" (#rrggbb), "type",
/// "values"}]} from Telegram's chart JSON: "columns" carries the x row and
/// one row per series, "names", "colors" and "types" are keyed by its id.
/// Nil for JSON that has no x row or no series.
NSDictionary *TGStatChartParse(NSString *json);

/// The largest value any series reaches, at least 1, for the y scale.
double TGStatChartMax(NSDictionary *chart);

#ifdef __cplusplus
}
#endif
