//+------------------------------------------------------------------+
//|                                                         5120.mq4 |
//|                                                     Victor Whyte |
//|                           https://linkedin.com/in/thevictorwhyte |
//+------------------------------------------------------------------+
#define SIGNAL_NONE 0
#define SIGNAL_BUY   1
#define SIGNAL_SELL  2
#define SIGNAL_CLOSEBUY 3
#define SIGNAL_CLOSESELL 4

#property copyright "Victor Whyte"
#property link      "https://linkedin.com/in/thevictorwhyte"
#property version   "1.00"
//#property strict

extern int MagicNumber = 12345;
extern bool SignalMail = False;
extern double Lots = 1.0;
extern int Slippage = 3;
extern bool UseStopLoss = True;
extern int StopLoss = 30;
extern bool UseTakeProfit = False;
extern int TakeProfit = 0;
extern bool UseTrailingStop = True;
extern int TrailingStop = 30;

int P = 1;
int Order = SIGNAL_NONE;
int Total, Ticket, Ticket2;
double StopLossLevel, TakeProfitLevel, StopLevel;
bool isLongTrade;

int trailingStopCount = 0;

// DECLARE VARIABLES
double Ema10D, Ema120, Ema120_1, Ema120_2, Ema5, Ema5_1, Ema5_2, Ema13, Ema25;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+

double getStopLoss(bool isLgTrade) {
   double result = 0;
   for(int i = 1; i < 10; i++) {
      if(isLongTrade) {
         double lowPrice_1 = iLow(NULL, 0, i);
         double lowPrice_2 = iLow(NULL, 0, i+1);
         if(lowPrice_1 <= lowPrice_2) {
            result = lowPrice_1;
            break;
         }
      }
      
      if(!isLongTrade) {
         double highPrice_1 = iHigh(NULL, 0, i);
         double highPrice_2 = iHigh(NULL, 0, i+1);
         
         if(highPrice_1 >= highPrice_2) {
            result = highPrice_1;
            break;
         }
      }
   }
   
   return result;
}
int init() {
 if(Digits == 5 || Digits == 3 || Digits == 1)P = 10;else P = 1; // To account for 5 digit brokers

   return(0);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
int deinit(){
//---
   return(0);
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
int start() {
   Total = OrdersTotal();
   Order = SIGNAL_NONE;
   
   //+------------------------------------------------------------------+
   //| Variable Setup                                                   |
   //+------------------------------------------------------------------+
 
   Ema10D = iMA(NULL,1440,10,0,MODE_EMA,PRICE_CLOSE,1);

   Ema120 = iMA(NULL,0,120,0,MODE_EMA,PRICE_CLOSE,0);
   Ema5 = iMA(NULL,0,5,0,MODE_EMA,PRICE_CLOSE,0);
   
   Ema120_1 = iMA(NULL,0,120,0,MODE_EMA,PRICE_CLOSE,1);
   Ema120_2 = iMA(NULL,0,120,0,MODE_EMA,PRICE_CLOSE,2);
   Ema5_1 = iMA(NULL,0,5,0,MODE_EMA,PRICE_CLOSE,1);
   Ema5_2 = iMA(NULL,0,5,0,MODE_EMA,PRICE_CLOSE,2);
   Ema13 = iMA(NULL,0,13,0,MODE_EMA,PRICE_CLOSE,0);
   Ema25 = iMA(NULL,0,25,0,MODE_EMA,PRICE_CLOSE,0);
   
   double currentPrice = Open[0];
   
   StopLevel = (MarketInfo(Symbol(), MODE_STOPLEVEL) + MarketInfo(Symbol(), MODE_SPREAD)) / P; // Defining minimum StopLevel

   if (StopLoss < StopLevel) StopLoss = StopLevel;
   if (TakeProfit < StopLevel) TakeProfit = StopLevel;
   
   //+------------------------------------------------------------------+
   //| Variable Setup - END                                                   |
   //+------------------------------------------------------------------+
 
   // CHECK POSITION
   bool IsTrade = False;
   
   for(int i = 0; i < Total; i++) {
      Ticket2 = OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
      if(OrderType() <= OP_SELL &&  OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber) {
         IsTrade = True;
         if(OrderType() == OP_BUY) {
            //Close

            //+------------------------------------------------------------------+
            //| Signal Begin(Exit Buy)                                           |
            //+------------------------------------------------------------------+

            /* 5120 EXIT RULES:
               Exit the long trade when EMA(5) crosses EMA(25) from top
               Exit the short trade when EMA(5) crosses SMA(25) from bottom
               30 pips hard stop (30pips from initial entry price)
               Trailing stop of 30 pips
            */
            //Code Exit Rules!
            if(trailingStopCount >= 1) {
                if(Ema5 < Ema25) Order = SIGNAL_CLOSEBUY; // Rule to EXIT a Long trade
            }

            //+------------------------------------------------------------------+
            //| Signal End(Exit Buy)                                             |
            //+------------------------------------------------------------------+
            
            if (Order == SIGNAL_CLOSEBUY) {
               Ticket2 = OrderClose(OrderTicket(), OrderLots(), Bid, Slippage, MediumSeaGreen);
               if (SignalMail) SendMail("[Signal Alert]", "[" + Symbol() + "] " + DoubleToStr(Bid, Digits) + " Close Buy");
               IsTrade = False;
               trailingStopCount = 0;
               continue;
            }
            //Trailing stop
            if(UseTrailingStop && TrailingStop > 0) {                 
               if(Bid - OrderOpenPrice() > P * Point * TrailingStop) {
                  if(OrderStopLoss() < Bid - P * Point * TrailingStop) {
                     Ticket2 = OrderModify(OrderTicket(), OrderOpenPrice(), Bid - P * Point * TrailingStop, OrderTakeProfit(), 0, MediumSeaGreen);
                     trailingStopCount++;
                     continue;
                  }
               }
            }
         } else {
            //Close

            //+------------------------------------------------------------------+
            //| Signal Begin(Exit Sell)                                          |
            //+------------------------------------------------------------------+
            if(trailingStopCount >= 1) {
               if (Ema5 > Ema25) Order = SIGNAL_CLOSESELL; // Rule to EXIT a Short trade
            }
            
            //+------------------------------------------------------------------+
            //| Signal End(Exit Sell)                                            |
            //+------------------------------------------------------------------+
            if (Order == SIGNAL_CLOSESELL) {
               Ticket2 = OrderClose(OrderTicket(), OrderLots(), Ask, Slippage, DarkOrange);
               if (SignalMail) SendMail("[Signal Alert]", "[" + Symbol() + "] " + DoubleToStr(Ask, Digits) + " Close Sell");
               IsTrade = False;
               trailingStopCount = 0;
               continue;
            }
            //Trailing stop
            if(UseTrailingStop && TrailingStop > 0) {                 
               if((OrderOpenPrice() - Ask) > (P * Point * TrailingStop)) {
                  if((OrderStopLoss() > (Ask + P * Point * TrailingStop)) || (OrderStopLoss() == 0)) {
                     Ticket2 = OrderModify(OrderTicket(), OrderOpenPrice(), Ask + P * Point * TrailingStop, OrderTakeProfit(), 0, DarkOrange);
                     trailingStopCount++;
                     continue;
                  }
               }
            }
         }
         
         
      }
   }
   
    //+------------------------------------------------------------------+
   //| Signal Begin(Entries)                                            |
   //+------------------------------------------------------------------+

   /* 5120 ENTRY RULES:
      Enter a long trade when EMA(5) crosses EMA(120) from bottom AND price opened above EMA(10D)
      Enter a short trade when EMA(5) crosses EMA(120) from top AND price opened below EMA(10D)
   */

   // TDL 3: Code Entry Rules
   if(currentPrice > Ema10D) {
      //if (Ema5_2 < Ema120_2 && Ema5_1 >= Ema120_1) Order = SIGNAL_BUY; // Rule to ENTER a Long trade
      if ((Ema5_2 < Ema120_2 && Ema5_1 >= Ema120_1) || (Ema5_2 > Ema120_2 && Ema5_2 < Ema13 && Ema5_1 >= Ema13)) Order = SIGNAL_BUY;
   } else if(currentPrice < Ema10D) {
      //if (Ema5_2 > Ema120_2 && Ema5_1 <= Ema120_1) Order = SIGNAL_SELL; // Rule to ENTER a Short trade
      if ((Ema5_2 > Ema120_2 && Ema5_1 <= Ema120_1) || (Ema5_2 < Ema120_2 && Ema5_2 > Ema13 && Ema5_1 <= Ema13)) Order = SIGNAL_SELL;
   }else {
      Order = SIGNAL_NONE;
   }
   
   //+------------------------------------------------------------------+
   //| Signal End                                                       |
   //+------------------------------------------------------------------+
   
   //Buy
   if (Order == SIGNAL_BUY) {
     isLongTrade = True;
     StopLoss = MathAbs(MathRound(( (getStopLoss(isLongTrade) - currentPrice) / Point) / P ) );
     
     if(StopLoss <= 30) {
      StopLoss = 30;
     }
     
     Alert(StopLoss);
      if(!IsTrade) {
         //Check free margin
         if (AccountFreeMargin() < (1000 * Lots)) {
            Print("We have no money. Free Margin = ", AccountFreeMargin());
            return(0);
         }

         if (UseStopLoss) StopLossLevel = Ask - StopLoss * Point * P; else StopLossLevel = 0.0;
         if (UseTakeProfit) TakeProfitLevel = Ask + TakeProfit * Point * P; else TakeProfitLevel = 0.0;

         Ticket = OrderSend(Symbol(), OP_BUY, Lots, Ask, Slippage, StopLossLevel, TakeProfitLevel, "Buy(#" + MagicNumber + ")", MagicNumber, 0, DodgerBlue);
         if(Ticket > 0) {
            if (OrderSelect(Ticket, SELECT_BY_TICKET, MODE_TRADES)) {
				Print("BUY order opened : ", OrderOpenPrice());
                if (SignalMail) SendMail("[Signal Alert]", "[" + Symbol() + "] " + DoubleToStr(Ask, Digits) + " Open Buy");
			} else {
				Print("Error opening BUY order : ", GetLastError());
			}
         }
         return(0);
      }
   }

   //Sell
   if (Order == SIGNAL_SELL) {
      isLongTrade = False;
      StopLoss = MathAbs(MathRound(( (getStopLoss(isLongTrade) - currentPrice) / Point) / 10 ) );
      
      if(!IsTrade) {
         //Check free margin
         if (AccountFreeMargin() < (1000 * Lots)) {
            Print("We have no money. Free Margin = ", AccountFreeMargin());
            return(0);
         }

         if (UseStopLoss) StopLossLevel = Bid + StopLoss * Point * P; else StopLossLevel = 0.0;
         if (UseTakeProfit) TakeProfitLevel = Bid - TakeProfit * Point * P; else TakeProfitLevel = 0.0;

         Ticket = OrderSend(Symbol(), OP_SELL, Lots, Bid, Slippage, StopLossLevel, TakeProfitLevel, "Sell(#" + MagicNumber + ")", MagicNumber, 0, DeepPink);
         if(Ticket > 0) {
            if (OrderSelect(Ticket, SELECT_BY_TICKET, MODE_TRADES)) {
				Print("SELL order opened : ", OrderOpenPrice());
                if (SignalMail) SendMail("[Signal Alert]", "[" + Symbol() + "] " + DoubleToStr(Bid, Digits) + " Open Sell");
			} else {
				Print("Error opening SELL order : ", GetLastError());
			}
         }
         return(0);
      }
   }

  
  return(0);
}
//+------------------------------------------------------------------+
