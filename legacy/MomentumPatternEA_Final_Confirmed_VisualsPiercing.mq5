datetime lastCheckedCandle = 0;

// MomentumPatternEA_All9Patterns_NoSpam_CleanCompile.mq5
#property strict
#include <Trade/Trade.mqh>

input int MaxTrades = 1;
input double LotSize = 0.1;
input double TrailingStart = 30.0;
input double TrailingStep = 10.0;
input double TakeProfit = 2000;
input double StopLoss = 2000;

CTrade trade;

datetime lastSignalTimeBullishEngulfing = 0;
datetime lastSignalTimeBearishEngulfing = 0;
datetime lastSignalTimeBearNarami = 0;
datetime lastSignalTimeHammer = 0;
datetime lastSignalTimeBullCross = 0;
datetime lastSignalTimeBearCross = 0;
datetime lastSignalTimeBullPiercing = 0;
datetime lastSignalTimeBearPiercing = 0;
datetime lastSignalTimeDarkCloud = 0;

int rsi14Handle, rsi7Handle, rsi3Handle;
int ema20Handle, ema50Handle;

int OnInit()
{
   rsi14Handle = iRSI(_Symbol, PERIOD_CURRENT, 14, PRICE_CLOSE);
   rsi7Handle = iRSI(_Symbol, PERIOD_CURRENT, 7, PRICE_CLOSE);
   rsi3Handle = iRSI(_Symbol, PERIOD_CURRENT, 3, PRICE_CLOSE);

   ema20Handle = iMA(_Symbol, PERIOD_CURRENT, 20, 0, MODE_EMA, PRICE_CLOSE);
   ema50Handle = iMA(_Symbol, PERIOD_CURRENT, 50, 0, MODE_EMA, PRICE_CLOSE);

   if (rsi14Handle == INVALID_HANDLE || rsi7Handle == INVALID_HANDLE || rsi3Handle == INVALID_HANDLE ||
       ema20Handle == INVALID_HANDLE || ema50Handle == INVALID_HANDLE)
   {
      Print("Indicator handle error");
      return INIT_FAILED;
   }

   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   IndicatorRelease(rsi14Handle);
   IndicatorRelease(rsi7Handle);
   IndicatorRelease(rsi3Handle);
   IndicatorRelease(ema20Handle);
   IndicatorRelease(ema50Handle);
}

void OnTick()
{
{
   if (CountOpenTrades() >= MaxTrades)
      return;

   // Get time of the last closed candle
   datetime currentCandleTime = iTime(_Symbol, PERIOD_CURRENT, 1);

   // Only run detection logic once per completed candle
   if (currentCandleTime != lastCheckedCandle)
   {
      lastCheckedCandle = currentCandleTime;

      double rsi14[], rsi7[], rsi3[], ema20[], ema50[];
      if (CopyBuffer(rsi14Handle, 0, 0, 2, rsi14) < 2 ||
          CopyBuffer(rsi7Handle, 0, 0, 2, rsi7) < 2 ||
          CopyBuffer(rsi3Handle, 0, 0, 2, rsi3) < 2 ||
          CopyBuffer(ema20Handle, 0, 0, 2, ema20) < 2 ||
          CopyBuffer(ema50Handle, 0, 0, 2, ema50) < 2)
         return;

      // Bullish Engulfing
      if (IsBullishEngulfing()) {
         DrawArrow(true, "BullEngulf", currentCandleTime, iLow(_Symbol, PERIOD_CURRENT, 1));
         Alert("Confirmed Bullish Engulfing detected!");
         OpenBuy("BullishEngulfing");
      }

      // Bearish Engulfing
      if (IsBearishEngulfing()) {
         DrawArrow(false, "BearEngulf", currentCandleTime, iHigh(_Symbol, PERIOD_CURRENT, 1));
         Alert("Confirmed Bearish Engulfing detected!");
         OpenSell("BearishEngulfing");
      }

      // Bear Narami
      if (IsBearNarami()) {
         DrawArrow(false, "BearNarami", currentCandleTime, iHigh(_Symbol, PERIOD_CURRENT, 1));
         Alert("Confirmed Bear Narami detected!");
         OpenSell("BearNarami");
      }

      // Hammer
      if (IsHammer()) {
         DrawArrow(true, "Hammer", currentCandleTime, iLow(_Symbol, PERIOD_CURRENT, 1));
         Alert("Confirmed Hammer detected!");
         OpenBuy("Hammer");
      }

      // Bull Cross
      if (IsBullCross(rsi14, rsi7)) {
         DrawArrow(true, "BullCross", currentCandleTime, iLow(_Symbol, PERIOD_CURRENT, 1));
         Alert("Confirmed Bull Cross detected!");
         OpenBuy("BullCross");
      }

      // Bear Cross
      if (IsBearCross(rsi14, rsi7)) {
         DrawArrow(false, "BearCross", currentCandleTime, iHigh(_Symbol, PERIOD_CURRENT, 1));
         Alert("Confirmed Bear Cross detected!");
         OpenSell("BearCross");
      }

      // Bullish Piercing
      if (IsBullPiercing()) {
         DrawArrow(true, "BullPiercing", currentCandleTime, iLow(_Symbol, PERIOD_CURRENT, 1));
         Alert("Confirmed Bullish Piercing detected!");
         OpenBuy("BullPiercing");
      }

      // Bearish Piercing
      if (IsBearPiercing()) {
         DrawArrow(false, "BearPiercing", currentCandleTime, iHigh(_Symbol, PERIOD_CURRENT, 1));
         Alert("Confirmed Bearish Piercing detected!");
         OpenSell("BearPiercing");
      }

      // Dark Cloud
      if (IsDarkCloud()) {
         DrawArrow(false, "DarkCloud", currentCandleTime, iHigh(_Symbol, PERIOD_CURRENT, 1));
         Alert("Confirmed Dark Cloud detected!");
         OpenSell("DarkCloud");
      }
   }
}
}

// Placeholder pattern functions










int CountOpenTrades()
{
   int count = 0;
   for (int i = 0; i < PositionsTotal(); i++) {
      if (PositionGetSymbol(i) == _Symbol)
         count++;
   }
   return count;
}

bool IsBullishEngulfing()
{
   double o1 = iOpen(_Symbol, PERIOD_CURRENT, 2);
   double c1 = iClose(_Symbol, PERIOD_CURRENT, 2);
   double o2 = iOpen(_Symbol, PERIOD_CURRENT, 1);
   double c2 = iClose(_Symbol, PERIOD_CURRENT, 1);
   return (c1 < o1 && c2 > o2 && o2 < c1 && c2 > o1);
}

bool IsBearishEngulfing()
{
   double o1 = iOpen(_Symbol, PERIOD_CURRENT, 2);
   double c1 = iClose(_Symbol, PERIOD_CURRENT, 2);
   double o2 = iOpen(_Symbol, PERIOD_CURRENT, 1);
   double c2 = iClose(_Symbol, PERIOD_CURRENT, 1);
   return (c1 > o1 && c2 < o2 && o2 > c1 && c2 < o1);
}

bool IsBearNarami()
{
   double o1 = iOpen(_Symbol, PERIOD_CURRENT, 2);
   double c1 = iClose(_Symbol, PERIOD_CURRENT, 2);
   double o2 = iOpen(_Symbol, PERIOD_CURRENT, 1);
   double c2 = iClose(_Symbol, PERIOD_CURRENT, 1);
   return (c1 > o1 && o2 > c2 && o2 < o1 && c2 > c1);
}

bool IsHammer()
{
   double open = iOpen(_Symbol, PERIOD_CURRENT, 1);
   double close = iClose(_Symbol, PERIOD_CURRENT, 1);
   double high = iHigh(_Symbol, PERIOD_CURRENT, 1);
   double low = iLow(_Symbol, PERIOD_CURRENT, 1);
   double body = MathAbs(open - close);
   double lowerWick = MathMin(open, close) - low;
   double upperWick = high - MathMax(open, close);
   return (lowerWick > 2 * body && upperWick < body);
}

bool IsBullCross(double &ema20[], double &ema50[])
{
   return (ema20[1] < ema50[1] && ema20[0] > ema50[0]);
}

bool IsBearCross(double &ema20[], double &ema50[])
{
   return (ema20[1] > ema50[1] && ema20[0] < ema50[0]);
}

bool IsBullishPiercing()
{
   double o1 = iOpen(_Symbol, PERIOD_CURRENT, 2);
   double c1 = iClose(_Symbol, PERIOD_CURRENT, 2);
   double o2 = iOpen(_Symbol, PERIOD_CURRENT, 1);
   double c2 = iClose(_Symbol, PERIOD_CURRENT, 1);
   return (c1 < o1 && o2 < c1 && c2 > ((o1 + c1) / 2) && c2 < o1);
}

bool IsBearishPiercing()
{
   double o1 = iOpen(_Symbol, PERIOD_CURRENT, 2);
   double c1 = iClose(_Symbol, PERIOD_CURRENT, 2);
   double o2 = iOpen(_Symbol, PERIOD_CURRENT, 1);
   double c2 = iClose(_Symbol, PERIOD_CURRENT, 1);
   return (c1 > o1 && o2 > c1 && c2 < ((o1 + c1) / 2) && c2 > o1);
}

bool IsDarkCloud()
{
   return IsBearishPiercing();
}

double NormalizeLotSize(double lots) {
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   return MathMax(NormalizeDouble(lots, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)), minLot);
}

double NormalizePrice(double price) {
   return NormalizeDouble(price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
}

void OpenBuy(string reason) {
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double sl = NormalizePrice(ask - StopLoss * _Point);
   double tp = NormalizePrice(ask + TakeProfit * _Point);
   double vol = NormalizeLotSize(LotSize);
   trade.Buy(vol, _Symbol, ask, sl, tp, reason);
}

void OpenSell(string reason) {
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl = NormalizePrice(bid + StopLoss * _Point);
   double tp = NormalizePrice(bid - TakeProfit * _Point);
   double vol = NormalizeLotSize(LotSize);
   trade.Sell(vol, _Symbol, bid, sl, tp, reason);
}


void DrawArrow(bool isBuy, string labelPrefix, datetime time, double price) {
   string arrowName = labelPrefix + "_" + IntegerToString((int)time);
   string textName = "Label_" + arrowName;

   int arrowCode = isBuy ? 233 : 234; // Wingdings arrows

   // Draw arrow
   ObjectCreate(0, arrowName, OBJ_ARROW, 0, time, price);
   ObjectSetInteger(0, arrowName, OBJPROP_ARROWCODE, arrowCode);
   ObjectSetInteger(0, arrowName, OBJPROP_COLOR, isBuy ? clrLime : clrRed);
   ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, 2);

   // Add pattern label
   ObjectCreate(0, textName, OBJ_TEXT, 0, time, price + (isBuy ? 10 * _Point : -10 * _Point));
   ObjectSetInteger(0, textName, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, textName, OBJPROP_FONTSIZE, 10);
   ObjectSetString(0, textName, OBJPROP_TEXT, labelPrefix + " @ " + TimeToString(time, TIME_MINUTES));
}

bool IsBullPiercing() {
    double open1 = iOpen(_Symbol, PERIOD_CURRENT, 2);
    double close1 = iClose(_Symbol, PERIOD_CURRENT, 2);
    double open2 = iOpen(_Symbol, PERIOD_CURRENT, 1);
    double close2 = iClose(_Symbol, PERIOD_CURRENT, 1);

    if (close1 < open1 && close2 > open2) { // First red, second green
        double mid1 = open1 - (open1 - close1) / 2.0;
        return (open2 < close1 && close2 > mid1);
    }
    return false;
}

bool IsBearPiercing() {
    double open1 = iOpen(_Symbol, PERIOD_CURRENT, 2);
    double close1 = iClose(_Symbol, PERIOD_CURRENT, 2);
    double open2 = iOpen(_Symbol, PERIOD_CURRENT, 1);
    double close2 = iClose(_Symbol, PERIOD_CURRENT, 1);

    if (close1 > open1 && close2 < open2) { // First green, second red
        double mid1 = close1 - (close1 - open1) / 2.0;
        return (open2 > close1 && close2 < mid1);
    }
    return false;
}
