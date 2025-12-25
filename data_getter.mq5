//+------------------------------------------------------------------+
//|                                          data-for-prediction.mq5 |
//|                                              Paul Natividad 2024 |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Paul Natividad 2024"
#property link      "https://www.mql5.com"
#property version   "1.00"


//+------------------------------------------------------------------+
//| Input                                  
//+------------------------------------------------------------------+
//sinput group                  "Asian Session"
//input datetime                  asianStartTime                 = 0;
//input datetime                  asianEndTime                   = 0;

//+------------------------------------------------------------------+
//| Global Variables                                  
//+------------------------------------------------------------------+
// Define a global variable to store the time of the previous bar
datetime prevBarTimeLTF, prevBarTimeMTF, prevBarTimeHTF;

string pdailyDirection = "";

double currentHigh;
double currentLow;
double mr_high;
double mr_low;

double currentCandleHigh;
double currentCandleLow;
double previousCandleHigh;
double previousCandleLow;

double highValues [];
double lowValues [];
double openValues [];
double closeValues[];

string marketDirection = "";

//Previous HL Checker
bool prev_high_hit = false;
bool prev_low_hit = false;

//Inside bar
double ib_high;
double ib_low;
bool is_prev_ib = false;

bool is_breaking_highs = false;
bool is_breaking_lows = false;

//Momentum
string momentum = "Range";

//MSS
bool market_shift = false;
bool mss = false;

bool isMSSBullValid = false;
bool isMSSBearValid = false;

bool break_mrhigh = false;
bool break_mrlow = false;

bool isWickBreakMSS = false;

// Trade Variable
ulong magicNumber = 101;
bool plotterTradeSignal = false;
double tpHolder;

//Utilize in Normalization
double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE); // EU ticksize -> 0.00001

//--- Asian High and Low ---
// Define global variables to store Asian session high and low
double asianHighOfDay;
double asianLowOfDay;
MqlDateTime prevBarDate;
MqlDateTime currentDay;

// Timeframes Input
sinput group "Liquidity Session"
input ENUM_TIMEFRAMES ltf = PERIOD_CURRENT;// Lower Timeframe
input ENUM_TIMEFRAMES mtf = PERIOD_M15;  // Lower Timeframe
input ENUM_TIMEFRAMES htf = PERIOD_H1;  // Higher Timeframe

//ENUM_TIMEFRAMES dataTF[] = {PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_H1, PERIOD_H4, PERIOD_D1, PERIOD_W1}; // For Data Collection
ENUM_TIMEFRAMES dataTF[] = {PERIOD_M1, PERIOD_M15, PERIOD_H4, PERIOD_D1}; // For Data Collection

// Define the parameters for the Asian session
sinput group "Liquidity Session"
input int asianSessionStartHourGMT = 7;  // Asian session start hour in GMT
input int asianSessionEndHourGMT = 12;   // Asian session end hour in GMT

sinput group "Server Hours Offset"
input int gmtOffset = 5;  // Broker's GMT offset (GMT+8 for GMT+8 timezone)
int gmtOffsetPH = gmtOffset*3600;
datetime lastCalculationDate = 0;

bool asianLQ = false;

// Trading Session
sinput group "Trading Session"
input int tradeSessionStart = 14;  // 2PM GMT+8 PH Time
input int tradeSessionEndHour = 18; // 6PM GMT+8 PH Time
input double riskPercentage = 0.2; // 0.35% per trade
input int maxTradesPerDay = 4;
input bool trailSL = true;
int tradesToday = 0;

//input ENUM_DAY_OF_WEEK noTradeDay = ENUM_DAY_OF_WEEK::Friday;

sinput group "Risk to Reward Ratio"
input double tradeRR = 1;

input bool useFillingPolicy = true;
//Fill or Kill (FOK) Filling
input ENUM_ORDER_TYPE_FILLING fillingPolicy = ORDER_FILLING_FOK;


// *Supertrend
input int SuperTrend_Period = 7;
input double SuperTrend_Multiplier = 3;
input bool SuperTrend_Show_Filling = true;

double SuperTrendBuffer[];
double ColorBuffer[];

int SuperTrend_Handle[ArraySize(dataTF)];

double colorVals[ArraySize(dataTF)];   // Color value (uptrend or downtrend)
string trendStatuses[ArraySize(dataTF)];  // Trend status ("Uptrend", "Downtrend", etc.)
string STTrend[ArraySize(dataTF)] = {"notrend"};
bool STTrendChange[ArraySize(dataTF)];
double STVal[ArraySize(dataTF)];

datetime lastLoggedTime = 0;

// --- ATR
input int ATR_Period = 14;
int ATR_Handle[ArraySize(dataTF)];
double ATR_Buffer[];
double ATR_Value[ArraySize(dataTF)];

//+------------------------------------------------------------------+
//|   Market Structure Object                                        |
//+------------------------------------------------------------------+
class StructuredData{
  protected:
    ENUM_TIMEFRAMES tf;
    double objcurrentHigh;
    double objcurrentLow;
    double objmr_high;
    double objmr_low;
    double objcurrentCandleHigh;
    double objcurrentCandleLow;
    double objpreviousCandleHigh;
    double objpreviousCandleLow;
    string objmarketDirection;
    string objmomentum;
    bool objis_breaking_highs;
    bool objis_breaking_lows;
    bool objmarket_shift;
    bool objmss;
    double objhighValues [];
    double objlowValues [];
    double objopenValues [];
    double objcloseValues[];
    double obj_o, obj_h, obj_l, obj_c;
    bool objplotterTradeSignal;
    
    
  public:
    //Constructor; this will execute upon instantiation
    StructuredData(){
       objcurrentHigh = 0;
       objcurrentLow = 0;
       objmr_high = 0;
       objmr_low = 0;
       objmarketDirection = "ib";
       objmomentum = "Range";
       objis_breaking_highs = false;
       objis_breaking_lows = false;
       objmarket_shift = false;
       objmss = false;
       // Ensure Arrays are empty initially
       ArrayResize(openValues, 0);
       ArrayResize(highValues, 0);
       ArrayResize(lowValues, 0);
       ArrayResize(closeValues, 0);
       
       objplotterTradeSignal = false;
       tf = PERIOD_CURRENT;
    }
    
    //Set Timeframe
    void SetTimeframe (ENUM_TIMEFRAMES val) {
      tf = val;
    }
    
    // ------ On Tick Function ---
    void RunOnTickPlotter(string stTrend, bool stChange, double stVal, bool is_barClosed, double atrValue){
    
      // PLOTTER
      obj_o = iOpen(_Symbol, tf, 1);
      obj_o = NormalizeDouble(obj_o, _Digits);
      AddToArray(objopenValues, obj_o);
         
      obj_h = iHigh(_Symbol, tf, 1);
      obj_h = NormalizeDouble(obj_h, _Digits);
      AddToArray(objhighValues, obj_h);
         
      obj_l = iLow(_Symbol, tf, 1);
      obj_l = NormalizeDouble(obj_l, _Digits);
      AddToArray(objlowValues, obj_l);
         
      obj_c = iClose(_Symbol, tf, 1);
      obj_c = NormalizeDouble(obj_c, _Digits);
      AddToArray(objcloseValues, obj_c);
   
      objcurrentCandleHigh = objhighValues[0];
      objcurrentCandleLow = objlowValues[0];
      objpreviousCandleHigh = objhighValues[1];
      objpreviousCandleLow = objlowValues[1];

      //Call PlotStructure function
      PlotStructure(
         objcurrentHigh, 
         objcurrentLow, 
         objmr_high, 
         objmr_low, 
         objcurrentCandleHigh, 
         objcurrentCandleLow, 
         objpreviousCandleHigh, 
         objpreviousCandleLow, 
         objhighValues, 
         objlowValues, 
         objopenValues, 
         objcloseValues, 
         objmarketDirection, 
         objmomentum, 
         objis_breaking_highs, 
         objis_breaking_lows, 
         objmarket_shift, 
         objmss,
         break_mrhigh,
         break_mrlow);
        
         Print( " TF: ", EnumToString(tf), " | Direction: ", objmomentum, "| MSS: ", objmarket_shift, "| Current High: ", DoubleToString(objcurrentHigh, _Digits), " | Current Low: ", DoubleToString(objcurrentLow, _Digits), " | MR High: ", DoubleToString(objmr_high, _Digits), " | MR Low: ", DoubleToString(objmr_low, _Digits));
         
         //backtest time is on gmt+2 CEST
         
         string dataLine = StringFormat(
             "%s,%s,%s,%d,%d,%d,%f,%f,%d,%f,%f,%f,%f,%f,%f,%f",
             TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES), // Current timestamp
             EnumToString(tf),                                     // Timeframe (e.g., M15, H4)
             objmomentum,                                          // Direction
             break_mrhigh,                                         // Break MR High?
             break_mrlow,                                          // Break MR Low?
             objmarket_shift,                                      // MSS (int: 0 or 1)
             objcurrentHigh,                                       // Current high
             objcurrentLow,                                        // Current low
             is_barClosed,                                         // is_barclose
             objmr_high,                                           // Most recent high
             objmr_low,                                            // Most recent low
             objcurrentCandleHigh,                                 // Current candle high
             objcurrentCandleLow,                                  // Current candle low
             objpreviousCandleHigh,                                // Previous candle high
             objpreviousCandleLow,                                 // Previous candle low
             //stTrend,                                   // Supertrend trend (string)
             //stChange,                             // Supertrend trend change (boolean as int: 0 or 1)
             //stVal                                    // Supertrend value (double)
             (double)atrValue                                    //ATR
         );
         
         // Write data to file
         WriteDataToFile("au_market_data.csv", dataLine);
         // Print the full path for debugging
         string fileName = "au_market_data.csv";
         string fullPath = TerminalInfoString(TERMINAL_DATA_PATH) + "\\MQL5\\Files\\" + fileName;
         Print("Data should be saved at: ", fullPath);

    }
    
    

   // ------ On Init function ----------
   void RunOnInitPlotter(int plimit){
     
     // Get the index of the farthest bar from the current time frame
     int farthestBarIndex = MathMin(Bars(Symbol(), tf), plimit); // limit to 3000
       
       
     // Check if the farthestBarIndex is valid
     if (farthestBarIndex >= 0)
     {
       
       // Retrieve the datetime of the farthest bar
       datetime farthestBarTime = iTime(Symbol(), tf, farthestBarIndex);
           
       // Now you can use this datetime as needed
       Print("Datetime of the farthest bar: ", TimeToString(farthestBarTime));
           
       //Arrays
       int bIndex = 1;
           
           
       // Plot highs and lows from the farthest bar to the current bar
       for (int i = farthestBarIndex; i > 0; i--){
           
         datetime barTime = iTime(Symbol(), tf, i);
         TimeToStruct(barTime, currentDay);
            
         if (currentDay.day != prevBarDate.day) {
           asianHighOfDay = -DBL_MAX;
           asianLowOfDay = DBL_MAX;
                
           // Update the datetime of the previous bar
           prevBarDate = currentDay;
         }
         
            
         obj_o = iOpen(_Symbol, tf,i);
         obj_o = NormalizeDouble(obj_o, _Digits);
         AddToArray(objopenValues, obj_o);
            
         obj_h = iHigh(_Symbol, tf, i);
         obj_h = NormalizeDouble(obj_h, _Digits);
         AddToArray(objhighValues, obj_h);
            
         obj_l = iLow(_Symbol, tf, i);
         obj_l = NormalizeDouble(obj_l, _Digits);
         AddToArray(objlowValues, obj_l);
            
         obj_c = iClose(_Symbol, tf,i);
         obj_c = NormalizeDouble(obj_c, _Digits);
         AddToArray(objcloseValues, obj_c);
            
         //Set
         objcurrentCandleHigh = objhighValues[0];
         objcurrentCandleLow = objlowValues[0];
         if( farthestBarIndex > i){
           objpreviousCandleHigh = objhighValues[1];
           objpreviousCandleLow = objlowValues[1];
         }
            
         if(bIndex == 1){
           objcurrentHigh = objcurrentCandleHigh;
           objcurrentLow = objcurrentCandleLow;
           objmr_high = objcurrentHigh;
           objmr_low = objcurrentLow;
               
           bIndex =0;
         }else{
           //Call PlotStructure function
            PlotStructure(
               objcurrentHigh, 
               objcurrentLow, 
               objmr_high, 
               objmr_low, 
               objcurrentCandleHigh, 
               objcurrentCandleLow, 
               objpreviousCandleHigh, 
               objpreviousCandleLow, 
               objhighValues, 
               objlowValues, 
               objopenValues, 
               objcloseValues, 
               objmarketDirection, 
               objmomentum, 
               objis_breaking_highs, 
               objis_breaking_lows, 
               objmarket_shift, 
               objmss,
               break_mrhigh,
               break_mrlow);
         }
         Print(" TF: ", EnumToString(tf), "| Direction: ", objmomentum, "| MSS: ", objmarket_shift, " | Bar index: ", i, "| Datetime: ", TimeToString(barTime + gmtOffsetPH), "| Current High: ", DoubleToString(objcurrentHigh, _Digits), " | Current Low: ", DoubleToString(objcurrentLow, _Digits), " | Prev High: ", DoubleToString(objmr_high, _Digits), " | Prev Low: ", DoubleToString(objmr_low, _Digits));
         
         //CALCULATE ASIAN HIGHLOW
         CalculateAsianHighLow(barTime + gmtOffsetPH, asianHighOfDay, asianLowOfDay, i);
         
       }//---------> End of FOR LOOP <------------
       
     }
   }
    
    //Getter Methods
    ENUM_TIMEFRAMES GetTimeFrame(){
      return tf;
    }
};


//+------------------------------------------------------------------+
//| Instantiate Objects                                              |
//+------------------------------------------------------------------+
StructuredData dataTFObj[ArraySize(dataTF)];
//StructuredData mtfObject;
//StructuredData htfObject;


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
    for(int i = 0 ; i < ArraySize(dataTF); i++ ){
    
      // Set Timeframe
      dataTFObj[i].SetTimeframe(dataTF[i]);
      dataTFObj[i].RunOnInitPlotter(60);
    
      // Load SuperTrend Indicator
      SuperTrend_Handle[i] = iCustom(_Symbol, dataTF[i], "supertrend", SuperTrend_Period, SuperTrend_Multiplier, SuperTrend_Show_Filling);
      
      if(SuperTrend_Handle[i] == INVALID_HANDLE){
         Print("Failed to load/initialize Supertrend Indicator");
         return(INIT_FAILED);
       }
       ArraySetAsSeries(SuperTrendBuffer, true);
       ArraySetAsSeries(ColorBuffer, true);
       
    //ATR
    ATR_Handle[i] = iATR(_Symbol, dataTF[i], ATR_Period);

    if(ATR_Handle[i] == INVALID_HANDLE)
    {
        Print("Failed to load ATR on ", EnumToString(dataTF[i]));
        return INIT_FAILED;
    }
    
    // Validate the handle by attempting a small copy
    double tempATR[1];
    if(CopyBuffer(ATR_Handle[i], 0, 0, 1, tempATR) < 0)
    {
        Print("ATR Handle created but data not yet ready for ", EnumToString(dataTF[i]));
    }
       
    } // end of for loop
    
  
    // Object Init Function
    //ltfObject.SetTimeframe(PERIOD_M15);
    //ltfObject.RunOnInitPlotter(58400);
    //mtfObject.SetTimeframe(PERIOD_H4);
    //mtfObject.RunOnInitPlotter(3650);
    //htfObject.SetTimeframe(PERIOD_D1);
    //htfObject.RunOnInitPlotter(730);
    
    
    
    //Print(mtfObject.GetTimeFrame());
    
    // Initialize prevBarTime with the time of the previous bar
    prevBarTimeLTF = iTime(_Symbol, ltf, 1); // Time of the bar before the current one; running on m15
    //prevBarTimeMTF = iTime(_Symbol, mtf, 1); 
    //prevBarTimeHTF = iTime(_Symbol, htf, 1);
    
    //Print("w/out: ", Bars(Symbol(), Period()) );
    //Print("with - 1: ", Bars(Symbol(), Period()) - 1);
    //Print(Bias(PERIOD_D1));
    
    
    //Print(iTime(_Symbol, PERIOD_CURRENT, 0) - TimeGMTOffset() + 8*3600);
   
   return(INIT_SUCCEEDED);
  }
  
  
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   for(int i = 0 ; i < ArraySize(dataTF); i++ ){
       if(SuperTrend_Handle[i] != INVALID_HANDLE){
         IndicatorRelease(SuperTrend_Handle[i]);
       }
       // Release ATR handles
       if(ATR_Handle[i] != INVALID_HANDLE){
         IndicatorRelease(ATR_Handle[i]);
         ATR_Handle[i] = INVALID_HANDLE;
       }
   }
  }
  
  
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
    // Get the time of the previous tick
    datetime prevTickTime = prevBarTimeLTF;
    // Get the time of the current bar -- we'll run this on m15 Chart
    datetime currentBarTime = iTime(_Symbol, _Period, 1); // Last closed bar
    
    for(int i = 0 ; i < ArraySize(dataTF); i++ ){
       // Check if ST is loaded correctly
       if(SuperTrend_Handle[i] == INVALID_HANDLE){
         return;   
       }
       
       //Get current bar's ST and ColorBuffer values
       if(CopyBuffer(SuperTrend_Handle[i], 2, 0, 1, SuperTrendBuffer) <0 || CopyBuffer(SuperTrend_Handle[i], 3, 0, 1, ColorBuffer) <=0 ){
         Print("Failed to get ST values, Error: ", GetLastError());
         return;   
       }
       
       STVal[i] = round(SuperTrendBuffer[0]/tickSize)*tickSize;
       STVal[i] = NormalizeDouble(STVal[i], _Digits);
       double colorVal = ColorBuffer[0]; // 0 for uptrend, 1 for downtrend
       //string trendStatus = "Notrend";
       
       // Store the colorVal for each timeframe
       colorVals[i] = colorVal;
       
       if(colorVal == 0 ){
         trendStatuses[i] = "Uptrend";   
       }else if (colorVal == 1){
         trendStatuses[i] = "Downtrend";
       }else{
         trendStatuses[i] = "Notrend";
       }
       
       
      // Inside OnTick loop
      if(ATR_Handle[i] != INVALID_HANDLE)
      {
          double tempBuffer[];
          ArraySetAsSeries(tempBuffer, true);
          
          // 1. Reset to 0 before copying
          ATR_Value[i] = 0.0; 
      
          if(CopyBuffer(ATR_Handle[i], 0, 1, 1, tempBuffer) > 0)
          {
              // 2. Normalizing ensures it is a clean double for the CSV
              ATR_Value[i] = NormalizeDouble(tempBuffer[0], _Digits);
          }
      }


       
       
    }
   
   //--------------------------
   //   Bar Confirmed/Closed
   //--------------------------
   // Get current time
    datetime currentTime = TimeCurrent();
    MqlDateTime currentTimeStruct;
    TimeToStruct(currentTime, currentTimeStruct);

    // Get the last logged time's minute
    MqlDateTime lastLoggedTimeStruct;
    TimeToStruct(lastLoggedTime, lastLoggedTimeStruct);
   
   //if(prevTickTime != currentBarTime){
   if (currentTimeStruct.min != lastLoggedTimeStruct.min){
      lastLoggedTime = TimeCurrent();
      //Assign supertrend
      for (int i = 0 ; i < ArraySize(dataTF); i++){
         if(trendStatuses[i] != STTrend[i]){
           STTrend[i] = trendStatuses[i];
           STTrendChange[i] = true;
         }else{
            STTrendChange[i] = false;
         }
         //Print("Supertrend: ", STTrend[i], " | ", "ST Trend Change: ", STTrendChange[i], " | ST Value: ", STVal[i]);

         // Pass data
         dataTFObj[i].RunOnTickPlotter(STTrend[i], STTrendChange[i], STVal[i], IsBarClosed(dataTF[i]), ATR_Value[i]);
      }
      
      // Collect Data
      //ltfObject.RunOnTickPlotter();
 
      //Print Plot HL Values 
      //datetime barTime = iTime(Symbol(), Period(), 1);
      
      // Update prevBarTime with the time of the current bar - for bar completion
      prevBarTimeLTF = currentBarTime;
      
   }
   
   //correct
    //datetime currGMT = TimeGMT();
    //currGMT += 8 * 60 * 60;
    //Print("MNL: ", TimeToString(currGMT));
    //Print(DailyBias());
    //Print(TimeGMTOffset());

  }
//+------------------------------ END of On Tick ------------------------------------+


datetime GMTManilaTime(datetime pGmTime){
   pGmTime += 8 * 3600;
   
   return pGmTime;
}

//+------------------------------------------------------------------+
//| Function to check if the current bar is closed for a given TF    |
//+------------------------------------------------------------------+
bool IsBarClosed(ENUM_TIMEFRAMES tf)
{
    // Get the current time of the last tick on the chart
    datetime currentTime = TimeCurrent();

    // Calculate the last bar's open time for the passed timeframe
    datetime lastClosedBarTime = iTime(Symbol(), tf, 1);
    
    // Calculate the period in minutes for the timeframe
    int periodMinutes = PeriodInMinutes(tf);
    
    // Check if the current time is divisible by the period in minutes (i.e., if the bar is closed)
    if ((currentTime - lastClosedBarTime) / 60 % periodMinutes == 0)  // Convert seconds to minutes
    {
        return true; // The bar is closed
    }
    else
    {
        return false; // The bar is not closed
    }
}

// Function to convert the period in minutes for the given timeframe
int PeriodInMinutes(ENUM_TIMEFRAMES tf)
{
    switch (tf)
    {
        case PERIOD_M1:  return 1;        // 1 minute
        case PERIOD_M5:  return 5;        // 5 minutes
        case PERIOD_M15: return 15;       // 15 minutes
        case PERIOD_M30: return 30;       // 30 minutes
        case PERIOD_H1:  return 60;       // 1 hour
        case PERIOD_H4:  return 240;      // 4 hours
        case PERIOD_D1:  return 1440;     // 1 day
        case PERIOD_W1:  return 10080;    // 1 week
        case PERIOD_MN1: return 43200;   // 1 month (approx. 30 days)
        default:         return 0;        // Invalid timeframe
    }
}

// ------------- // Price Functions //-------------//

double Close(int pShift, ENUM_TIMEFRAMES pTimeFrame){
   MqlRates bar[]; // It creates an object array of MqlRates Structure
   ArraySetAsSeries(bar, true);  // it sets our array as a series (current bar is position 0, prev bar is 1...)
   CopyRates(_Symbol,pTimeFrame,0,3,bar); // It copies the bar price info of bars position 0, 1 and 2 to our array 'bar'.

   return bar[pShift].close;
}

double Open(int pShift, ENUM_TIMEFRAMES pTimeFrame){
   MqlRates bar[];
   ArraySetAsSeries(bar, true);
   CopyRates(_Symbol, pTimeFrame, 0, 3, bar);
   
   return bar[pShift].open;
}

double High(int pShift, ENUM_TIMEFRAMES pTimeFrame){
   MqlRates bar[];
   ArraySetAsSeries(bar, true);
   CopyRates(_Symbol, pTimeFrame, 0, 3, bar);
   
   return bar[pShift].high;
}


double Low(int pShift, ENUM_TIMEFRAMES pTimeFrame){
   MqlRates bar[];
   ArraySetAsSeries(bar, true);
   CopyRates(_Symbol, pTimeFrame, 0, 3, bar);
   
   return bar[pShift].low;
}


//--------------------------------
//    ALGO Function
//--------------------------------

// DAILY BIAS
string Bias(ENUM_TIMEFRAMES tf){
   
   // Latest Completed Bar
   double dhighValue = High(1, tf);
   dhighValue = NormalizeDouble(dhighValue, _Digits);
   double dlowValue = Low(1, tf);
   dlowValue = NormalizeDouble(dlowValue, _Digits);
   double dopenValue = Open(1, tf);
   dopenValue = NormalizeDouble(dopenValue, _Digits);
   double dcloseValue = Close(1, tf);
   dcloseValue = NormalizeDouble(dcloseValue, _Digits);
   
   // Most Recent Completed Bar
   double mr_dhighValue = High(2, tf);
   mr_dhighValue = NormalizeDouble(mr_dhighValue, _Digits);
   double mr_dlowValue = Low(2, tf);
   mr_dlowValue = NormalizeDouble(mr_dlowValue, _Digits);
   double mr_dopenValue = Open(2, tf);
   mr_dopenValue = NormalizeDouble(mr_dopenValue, _Digits);
   double mr_dcloseValue = Close(2, tf);
   mr_dcloseValue = NormalizeDouble(mr_dcloseValue, _Digits);

   // Body Break
   if(dcloseValue < mr_dlowValue || dcloseValue > mr_dhighValue){
      
      // Break on High and Low
      if ( dhighValue > mr_dhighValue && dlowValue < mr_dlowValue ){
         // Check if Bear/Bullish Candle
         if( dcloseValue > dopenValue ){
            //bias is bullish
            return "bullish";
         }else if(dcloseValue < dopenValue){
            //bias is bearish
            return "bearish";
         }
         else{
            return "na";
         }
         
      }else if(dcloseValue > mr_dhighValue){
         // Bullish
         return "bullish";
      }else if(dcloseValue < mr_dlowValue){
         // Bearish
         return "bearish";
      }else{
         return "na";
      }
      
   }
   
   // Wicked Break: Break high and low
   else if( (dcloseValue < mr_dhighValue && dcloseValue > mr_dlowValue) && (dhighValue > mr_dhighValue || dlowValue < mr_dlowValue) ){
     // Check if Bear/Bullish Candle
      if( dcloseValue > dopenValue ){
         //bias is bullish
         return "bullish";
      }
      else if(dcloseValue < dopenValue){
         //bias is bearish
         return "bearish";
      }
      else{
         return "na";
      }
   }
   // Wicked Break: Break high w/out breaking prev. candle low
   else if(dhighValue > mr_dhighValue && dlowValue >= mr_dlowValue){
      //bias is bullish
      return "bullish";
   }
   // Wicked Break: Break high w/out breaking prev. candle low
   else if(dlowValue < mr_dlowValue && dhighValue >= mr_dhighValue){
      //bias is bullish
      return "bearish";
   }
   
   // Inside Bar
   return "n/a";
}

// --------- PLOT H/L -------------
void PlotStructure(
   double &pcurrentHigh,
   double &pcurrentLow,
   double &pmr_high,
   double &pmr_low,
   double &pcurrentCandleHigh,
   double &pcurrentCandleLow,
   double &ppreviousCandleHigh,
   double &ppreviousCandleLow,
   double &phighValues[],
   double &plowValues[],
   double &popenValues[],
   double &pcloseValues[],
   string &pmarketDirection,
   string &pmomentum,
   bool &pis_breaking_highs,
   bool &pis_breaking_lows,
   bool &pmarket_shift,
   bool &pmss,
   bool &pbreak_mrhigh,
   bool &pbreak_mrlow
){
   
   // Breaks both High and Low of the MOST PREV H/L
   if ( pmr_low != EMPTY_VALUE && pmr_high != EMPTY_VALUE && pcurrentCandleHigh > ppreviousCandleHigh && pcurrentCandleLow < ppreviousCandleLow){
   
      //-- updated version
         if (pcurrentCandleHigh > pmr_high && pcurrentCandleLow < pmr_low){
            
            pbreak_mrhigh = true;
            pbreak_mrlow = true;
            
            if (pmr_high < pcloseValues[0] && mr_low < popenValues[0]){
               if ( pmomentum == "Range" || pmomentum == "Bear"){
                  pmarket_shift = true;
                  pmomentum = "Bull";
               }else{
                  pmarket_shift = false;
               }
               
               pcurrentHigh = pcurrentCandleHigh;
               pmr_high = pcurrentHigh;
               pcurrentLow = pcurrentCandleLow;
               pmr_low = pcurrentLow;
            }
            //-here
            else if(pmr_low > pcloseValues[0] && pmr_high > popenValues[0]){
               if (pmomentum == "Range" || pmomentum == "Bull"){
                  pmarket_shift = true;
                  pmomentum = "Bear";
               }else{
                  pmarket_shift = false;
               }
               
               pcurrentHigh = pcurrentCandleHigh;
               pmr_high = pcurrentHigh;
               pcurrentLow = pcurrentCandleLow;
               pmr_low = pcurrentLow;
            }
            else if(pmr_high < pcloseValues[0]){
               if (pmomentum == "Range" || pmomentum == "Bear"){
                  pmarket_shift = true;
                  pmomentum = "Bull";
               }else{
                  pmarket_shift = false;
               }
               
               pcurrentHigh = pcurrentCandleHigh;
               pmr_high = pcurrentHigh;
               pcurrentLow = pcurrentCandleLow;
               pmr_low = pcurrentLow;
            }
            else if(pmr_low > pcloseValues[0]){
               if(pmomentum == "Range" || pmomentum == "Bull"){
                  pmarket_shift = true;
                  pmomentum = "Bear";
               }else{
                  pmarket_shift = false;
               }
               
               pcurrentHigh = pcurrentCandleHigh;
               pmr_high = pcurrentHigh;
               pcurrentLow = pcurrentCandleLow;
               pmr_low = pcurrentLow;
            }
            else{
               pmomentum = "Range";
               pmarket_shift = false;
               
               pcurrentHigh = pcurrentCandleHigh;
               pmr_high = pcurrentHigh;
               pcurrentLow = pcurrentCandleLow;
               pmr_low = pcurrentLow;
            }
         }
         
         else if(pmr_high < pcurrentCandleHigh){
            if(pmomentum == "Range" || pmomentum == "Bear"){
               pmarket_shift = true;
               pmomentum = "Bull";
            }else{
               pmarket_shift = false;
            }
            
            pbreak_mrhigh = true;
            pbreak_mrlow = false;
               
            pcurrentHigh = pcurrentCandleHigh;
            pmr_high = pcurrentHigh;
            if(pcurrentCandleLow < pcurrentLow){
               pcurrentLow = pcurrentCandleLow;
               pmr_low = pcurrentLow;
            }else{
               pmr_low = pcurrentLow;
            }
         }
         else if(pmr_low > pcurrentCandleLow){
            if(pmomentum == "Range" || pmomentum == "Bull"){
               pmarket_shift = true;
               pmomentum = "Bear";
            }else{
               pmarket_shift = false;
            }
            
            pbreak_mrhigh = false;
            pbreak_mrlow = true;
               
            pcurrentLow = pcurrentCandleLow;
            pmr_low = pcurrentLow;
            if(pcurrentCandleHigh > pcurrentHigh){
               pcurrentHigh = pcurrentCandleHigh;
               pmr_high = pcurrentHigh;
            }else{
               pmr_high = pcurrentHigh;
            }
            
         }
         
         //Inside a range
         else if (pmarketDirection == "bull"){
            pcurrentHigh = pcurrentCandleHigh;
            
            if(pcurrentLow < pcurrentCandleLow){
               pcurrentCandleLow = pcurrentLow;
            }
         }
         else if (pmarketDirection == "bear"){
            pcurrentLow = pcurrentCandleLow;
            
            if(pcurrentHigh > pcurrentCandleHigh){
               pcurrentCandleHigh = pcurrentHigh;
            }
         }
         else if (pmarketDirection == "ib"){
            pcurrentHigh = pcurrentCandleHigh;
            pcurrentLow = pcurrentCandleLow;
         }
        
         
         pmarketDirection = "LQ";
         
      
      }
      // # BULLISH
      else if (pcurrentCandleHigh > ppreviousCandleHigh){
         pmarketDirection = "bull";
         
         // Set what it breaks or direction
         pis_breaking_highs = true;
         pis_breaking_lows = false;
         
         // Update Current High
         pcurrentHigh = pcurrentCandleHigh;
         
         // Check if we hit MR High
         if(pmr_high != EMPTY_VALUE && pcurrentHigh > pmr_high){
            //Check if mss is valid
            if(pcloseValues[0] > pmr_high){
               pmss = true;
            }
            else{
               pmss = false;
            }
            
            //Set new MR High
            pmr_high = pcurrentHigh;
            
            if (pmomentum == "Range" || pmomentum == "Bear"){
               pmarket_shift = true;
               pmomentum = "Bull";
            }else{
               pmarket_shift = false;
            }
            
           // Plot the previous low as Prev Low
           if (pcurrentLow != EMPTY_VALUE){
              pmr_low = pcurrentLow;
           }
           
           // Break MRHigh
           pbreak_mrhigh = true;
           pbreak_mrlow = false;
         }
         
      }
   
      // # BEARISH
      else if(pcurrentCandleLow < ppreviousCandleLow){
         pmarketDirection = "bear";
         
         //Set what it breaks or direction
         pis_breaking_highs = false;
         pis_breaking_lows = true;
         
         //Update current low
         pcurrentLow = pcurrentCandleLow;
         
         //Check if we hit the prev low
         if(pmr_low != EMPTY_VALUE && pcurrentLow < pmr_low){
            //Check if market shift is valid
            if(pmr_low > pcloseValues[0]){
               pmss = true;
            }
            else{
               pmss = false;
            }
            
            //Set new Prev High
            pmr_low = pcurrentLow;
            
            if(pmomentum == "Range" || pmomentum == "Bull"){
               pmarket_shift = true;
               pmomentum = "Bear";
            }else{
               pmarket_shift = false;
            }
            
            // Plot the previous low as Prev Low
            if (pcurrentHigh != EMPTY_VALUE){
               pmr_high = pcurrentHigh;
            }
            
            //Break MRlow
            pbreak_mrhigh = false;
            pbreak_mrlow = true;
         }
      }
      // # BEARISH END
      
      // # Inside Bar
      else{
         pmarketDirection = "ib";
         
         pmss = false;
         pmarket_shift = false;
         
         pbreak_mrhigh = false;
         pbreak_mrlow = false;
         
         if(pis_breaking_highs == true){
            pcurrentHigh = pcurrentCandleHigh;
            pcurrentLow = pcurrentCandleLow;
            pis_breaking_highs = false;
            pis_breaking_lows = true;
            
            if(pmr_high == EMPTY_VALUE){
               pmr_high = pcurrentHigh;
            }
         }
         else if (pis_breaking_lows == true){
            pcurrentHigh = pcurrentCandleHigh;
            pcurrentLow = pcurrentCandleLow;
            pis_breaking_highs = true;
            pis_breaking_lows = false;
            
            if(pmr_low == EMPTY_VALUE){
               pmr_low = pcurrentLow;
            }
         }
         
         // Check if we hit the Prev High
         if(pmr_high != EMPTY_VALUE && pcurrentHigh > pmr_high && pis_breaking_highs == true){
            pis_breaking_highs = false;
            pis_breaking_lows = true;
            pmr_high = pcurrentHigh;
         }
         //Check if we hit prev low
         else if(pmr_low != EMPTY_VALUE && pcurrentLow < pmr_low && pis_breaking_lows == true){
            pis_breaking_highs = true;
            pis_breaking_lows = false;
            pmr_low = pcurrentLow;
         }
      
      }
      // # Inside Bar END    
   
      //-- updated version end --
     
}
//PLOT H/L END


// Array; Add Value and Limit only to 5
void AddToArray(double &arrVariable [], double pval){

   ArrayResize(arrVariable, ArraySize(arrVariable) + 1);
   
   for(int i= ArraySize(arrVariable) - 1; i > 0; i--){
      arrVariable[i] = arrVariable[i-1];
   }
   arrVariable[0] = pval;
   
   if(ArraySize(arrVariable) > 5){
      ArrayResize(arrVariable, 5);
   }
   
}

//+------------------------------------------------------------------+
//| Write Data to CSV File                                           |
//+------------------------------------------------------------------+
void WriteDataToFile(string fileName, string dataLine){
   int fileHandle = FileOpen(fileName, FILE_WRITE | FILE_CSV | FILE_READ);
   
   if (fileHandle != INVALID_HANDLE){
      // Move to the end of the file for appending data
      FileSeek(fileHandle, 0, SEEK_END);
      
      // Write the data line
      FileWrite(fileHandle, dataLine);
      
      // Close the file to save changes
      FileClose(fileHandle);
   }else {
      Print("Failed to open the file: ", fileName, " | Error Code: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Calculate Asian session times                                    |
//+------------------------------------------------------------------+
// Function to check if a new day or a new daily candle has occurred
bool IsNewDay(datetime date)
{
    // Get the date component of the given time
    MqlDateTime dt;
    TimeToStruct(date, dt);

    // Check if the current date is different from the date of the last calculation
    if (dt.day != lastCalculationDate)
    {
        lastCalculationDate = dt.day; // Update the last calculation date
        return true; // Return true if a new day or a new daily candle has occurred
    }

    return false; // Return false otherwise
}

// Function to check if a given time is within the Asian session
bool IsAsianSession(datetime time)
{
    // Declare an MqlDateTime structure to store the components of the given time
    MqlDateTime dt;
    
    // Convert the datetime value to MqlDateTime
    TimeToStruct(time, dt);
    
    // Get the hour component from the MqlDateTime structure
    int hour = dt.hour;
    // Check if the hour is within the Asian session hours
    return (hour >= asianSessionStartHourGMT && hour < asianSessionEndHourGMT);
}

// Function to calculate Asian session high and low for a specific day
void CalculateAsianHighLow(datetime date, double &pasianHigh, double &pasianLow, int shift)
{  
    MqlDateTime dt;
    TimeToStruct(date, dt);
    int barHour = dt.hour;
    
    // Calculate the start and end times for the Asian session on the specified date
    //datetime asianSessionStart = TimeGMT() + (asianSessionStartHourGMT - gmtOffset) * 3600;
    //datetime asianSessionEnd = TimeGMT() + (asianSessionEndHourGMT - gmtOffset) * 3600;

    // Iterate through candles within the Asian session
    //for (datetime time = asianSessionStart; time < asianSessionEnd; time += Period())
    if(barHour >= 7 && barHour < 12)
    {
        double high = iHigh(Symbol(), Period(), shift);
        double low = iLow(Symbol(), Period(), shift);

        // Update Asian session high and low
        if (high > pasianHigh){
            pasianHigh = high;
        }
        if (low < pasianLow){
            pasianLow = low;
        }
        
        pasianHigh = round(pasianHigh/tickSize)*tickSize;
        pasianLow = round(pasianLow/tickSize)*tickSize;
            
        Print("Asian Session High: ",pasianHigh);
        Print("Asian Session Low ",pasianLow);
    }
}



// ------------- // Order Placement Function //-------------//

// Check if there is an existing position/trade
bool checkPlacedPosition(ulong pMagic){
  bool placedPosition = false;
  
  //Look for all the positions that are currently opened
  for(int i = PositionsTotal() - 1; i >= 0; i--){
      //Retrieve the ticket of the position that we are looking for
      ulong positionTicket = PositionGetTicket(i);
      PositionSelectByTicket(positionTicket);
      
      ulong posMagic = PositionGetInteger(POSITION_MAGIC);
      
      // pMagic is the number of our EA
      if (posMagic == pMagic){
         return placedPosition = true;
         break;
      }
  }
  
  return placedPosition;
}

// OPEN A TRADE
ulong OpenTrades(string pEntrySignal, ulong pMagicNumber, double pmr_high, double pmr_low, double priskPercentage, int &ptradeToday){
   // Buy positions open trades at Ask, close them at Bid
   // Sell positions open trades at Bid, close them at Ask
   
   double askPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bidPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double volumeSize;
   
   // Price must be normalized either to digits or ticksize
   askPrice = round(askPrice/tickSize)*tickSize;
   bidPrice = round(bidPrice/tickSize)*tickSize;
   
   string comment = pEntrySignal + " | " + _Symbol + " | " + string(pMagicNumber);
   
   // Request and Result Declaration
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   //LONG ORDER
   if (pEntrySignal == "LONG"){
   
      //Calculate Volume
      volumeSize = CalculateLotSize(askPrice, pmr_low, priskPercentage);
      
      //REQUEST Parameters
      request.action    = TRADE_ACTION_DEAL;
      request.symbol    = _Symbol;
      request.volume    = volumeSize;
      request.type      = ORDER_TYPE_BUY;
      request.price     = askPrice;
      request.deviation = 10;
      request.magic     = pMagicNumber;
      request.comment   = comment;
      
      
      if(fillingPolicy == true){
         request.type_filling = fillingPolicy;
      }
      
      if (!OrderSend(request, result)){
         Print("OrderSend trade placement error: ", GetLastError()); //If req was not send, print error code.
      }else{
         ptradeToday++;
      }
      
      // Trade Information
      Print("Open: ", request.symbol, " ", pEntrySignal, " order #: ", result.order, ": ", result.retcode, " | Volume: ", result.volume, " | Price: ", DoubleToString(askPrice, _Digits));
      
      
      
   }
   //SHORT ORDER
   else if (pEntrySignal == "SHORT"){
      
      //Calculate Volume
      volumeSize = CalculateLotSize(bidPrice, pmr_high, priskPercentage);
      
      //REQUEST Parameters
      request.action    = TRADE_ACTION_DEAL;
      request.symbol    = _Symbol;
      request.volume    = volumeSize;
      request.type      = ORDER_TYPE_SELL;
      request.price     = bidPrice;
      request.deviation = 10;
      request.magic     = pMagicNumber;
      request.comment   = comment;
      
      
      if(fillingPolicy == true){
         request.type_filling = fillingPolicy;
      }
      
      if (!OrderSend(request, result)){
         Print("OrderSend trade placement error: ", GetLastError()); //If req was not send, print error code.
      }else{
         ptradeToday++;
      }
      
      // Trade Information
      Print("Open: ", request.symbol, " ", pEntrySignal, " order #: ", result.order, ": ", result.retcode, " | Volume: ", result.volume, " | Price: ", DoubleToString(bidPrice, _Digits));
      
   }
   
   if(result.retcode == TRADE_RETCODE_DONE || result.retcode == TRADE_RETCODE_DONE_PARTIAL || result.retcode == TRADE_RETCODE_PLACED || result.retcode == TRADE_RETCODE_NO_CHANGES){
   
      return result.order;
      
   }else return 0;
}

// Closing of Trade
void CloseTrade(ulong pMagic, string pExitSignal){
   
   // Request and Result Declaration and Initialization
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   for(int i = PositionsTotal() - 1; i >= 0; i--){
      // Reset of request and result values
      ZeroMemory(request);
      ZeroMemory(result);
      
      //Retrieve the ticket of the position that we are looking for
      ulong positionTicket = PositionGetTicket(i);
      PositionSelectByTicket(positionTicket);
      
      ulong posMagic = PositionGetInteger(POSITION_MAGIC);
      ulong posType = PositionGetInteger(POSITION_TYPE);
      
      //Close Buy Position
      if(posMagic == pMagic && pExitSignal == "EXIT_LONG" && posType == ORDER_TYPE_BUY){
         request.action = TRADE_ACTION_DEAL;
         request.type = ORDER_TYPE_SELL;
         request.symbol = _Symbol;
         request.position = positionTicket;
         request.volume = PositionGetDouble(POSITION_VOLUME);
         request.price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         request.deviation = 10;
         
         bool sent = OrderSend(request, result);
         if (sent == true){
            Print("Position #: ", positionTicket, " CLOSED.");
         } 
      }
      //Close Sell Position
      else if(posMagic == pMagic && pExitSignal == "EXIT_SHORT" && posType == ORDER_TYPE_SELL){
         request.action = TRADE_ACTION_DEAL;
         request.type = ORDER_TYPE_BUY;
         request.symbol = _Symbol;
         request.position = positionTicket;
         request.volume = PositionGetDouble(POSITION_VOLUME);
         request.price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         request.deviation = 10;
         
         bool sent = OrderSend(request, result);
         if (sent == true){
            Print("Position #: ", positionTicket, " CLOSED.");
         } 
      }
   }
}

//--------------
// Set SL & TP
//--------------
void TradeModification(ulong ticket, ulong pMagic, double pSLPrice, double pTPPrice){
   
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.action = TRADE_ACTION_SLTP;
   request.position = ticket;
   request.symbol = _Symbol;
   request.sl = round(pSLPrice/tickSize) * tickSize;
   request.tp = round(pTPPrice/tickSize) * tickSize;
   request.comment = "MOD " + " | " + _Symbol + " | " + string(pMagic) + " | SL: " + DoubleToString(request.sl, _Digits) + " | TP: " + DoubleToString(request.tp, _Digits);
   
   if(request.sl > 0 || request.tp > 0){
      Sleep(1000);
      bool sent = OrderSend(request, result);
      Print(result.comment);
      
      if(!sent){
         Print("Order sent modification error", GetLastError());
         Sleep(3000);
         
         //Try to send again the order.
         sent = OrderSend(request, result);
         Print(result.comment);
         if(!sent){Print("Order sent second try, modification error", GetLastError());}
         
      }
   }
}


// Calculate LOT SIZE
double CalculateLotSize(double entryPrice, double stopLossPrice, double priskPercentage)
{
    // Calculate distance in pips
    double pips = MathAbs(entryPrice - stopLossPrice)/Point();

    // Get account equity
    double accountEquity = AccountInfoDouble(ACCOUNT_BALANCE);
   
    // Calculate risk amount
    double riskAmount = accountEquity * priskPercentage / 100;
    
    //Get Tick Value
    //double tickVal = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);

    // Calculate lot size
    double lotSize = riskAmount / pips;
    lotSize = NormalizeDouble(lotSize, 2);
    Print("VOLUME: ", lotSize);
    return lotSize;
}


// Calculate TP
double CalculateTP(string pEntrySignal, double pstopLossPrice ,double ptradeRR){
   double takeprofit = 0.0;
   double askPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bidPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   // Calculate distance in pips
   double pips;
    
   if( pEntrySignal == "LONG"){
      pips = MathAbs(askPrice - pstopLossPrice);
      takeprofit = askPrice + (pips * ptradeRR);    
   }
   
   else if( pEntrySignal == "SHORT"){
      pips = MathAbs(bidPrice - pstopLossPrice);
      takeprofit = bidPrice - (pips * ptradeRR);   
   }
   
   takeprofit = round(takeprofit/tickSize) * tickSize;
   return takeprofit;
}


// Calculate SL
double CalculateSL(string pEntrySignal, int pSLFixedPoints){
   
   double stoploss = 0.0;
   
   double askPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bidPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   if( pEntrySignal == "LONG"){
   
      if(pSLFixedPoints > 0){
         stoploss = bidPrice - (pSLFixedPoints * _Point); // 1.11125 - (100 * 0.00001) = 1.11125 - 0.00100 = 1.11025      
      }

   }
   
   else if( pEntrySignal == "SHORT"){
   
      if(pSLFixedPoints > 0){
         stoploss = askPrice + (pSLFixedPoints * _Point); // 1.11125 - (100 * 0.00001) = 1.11125 - 0.00100 = 1.11025      
      }
      
   }
   
   
   stoploss = round(stoploss/tickSize)*tickSize;
   return stoploss;
}


// This will limit our trades per day
bool CanOpenTrade()
{
    // Check if we've reached the maximum number of trades per day
    if (tradesToday >= maxTradesPerDay)
    {
        return false; // We've reached the maximum trades allowed for today
    }
    
    // Check if there's already an open trade
    if (PositionsTotal() > 0 || OrdersTotal() > 0)
    {
        return false; // There's already an open trade
    }
    
    return true;
}

// Trail SL
void TrailingStoploss(ulong pMagic, double pmr_price){

   // Request and Result Declaration and Initialization
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   for(int i = PositionsTotal() - 1; i >= 0; i--){
      // Reset of request and result values
      ZeroMemory(request);
      ZeroMemory(result);
      
      //Retrieve the ticket of the position that we are looking for
      ulong positionTicket = PositionGetTicket(i);
      PositionSelectByTicket(positionTicket);
      
      ulong posMagic = PositionGetInteger(POSITION_MAGIC);
      ulong posType = PositionGetInteger(POSITION_TYPE);
      double currentSL = PositionGetDouble(POSITION_SL);
      double newSL;
      
      if(posMagic == pMagic && posType == ORDER_TYPE_BUY){
         double bidPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         newSL = pmr_price;
         
         newSL = round(newSL/tickSize)*tickSize; // normalize value
         
         if(newSL > currentSL){
            request.action = TRADE_ACTION_SLTP;
            request.position = positionTicket;
            request.comment = "TSL | " + _Symbol + " | " + string(pMagic);
            request.sl = newSL;
            request.tp = tpHolder;
            
            bool sent = OrderSend(request, result);
            if(sent == true){
               Print("SL moved to ", newSL);
            }else{
               Print("OrderSend Trailing SL error: ", GetLastError());
            }
         }
         
      }
      else if(posMagic == pMagic && posType == ORDER_TYPE_SELL){
         double askPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         newSL = pmr_price;
         
         newSL = round(newSL/tickSize)*tickSize; // normalize value
         
         if(newSL < currentSL){
            request.action = TRADE_ACTION_SLTP;
            request.position = positionTicket;
            request.comment = "TSL | " + _Symbol + " | " + string(pMagic);
            request.sl = newSL;
            request.tp = tpHolder;
            
            bool sent = OrderSend(request, result);
            if(sent == true){
               Print("SL moved to ", newSL);
            }else{
               Print("OrderSend Trailing SL error: ", GetLastError());
            }
         }
      }
      
   }

}

