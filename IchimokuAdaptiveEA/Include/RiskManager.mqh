//+------------------------------------------------------------------+
//|                                                  RiskManager.mqh |
//|                                Advanced Adaptive Risk Management |
//+------------------------------------------------------------------+
#property copyright "Ichimoku Adaptive EA"
#property link      ""
#property version   "1.00"

#include <Trade\AccountInfo.mqh>

//+------------------------------------------------------------------+
//| Risk Management Class                                             |
//+------------------------------------------------------------------+
class CRiskManager
{
private:
   CAccountInfo m_account;
   
   // Risk parameters
   double m_baseRiskPercent;
   double m_maxRiskPercent;
   double m_minRiskPercent;
   double m_currentRiskPercent;
   
   // Drawdown protection
   double m_maxDailyLoss;
   double m_maxWeeklyLoss;
   double m_dailyLoss;
   double m_weeklyLoss;
   datetime m_lastDayReset;
   datetime m_lastWeekReset;
   
   // Position limits
   int m_maxPositions;
   int m_maxDailyTrades;
   int m_dailyTradeCount;
   
   // Kelly Criterion
   double m_kellyFraction;
   bool m_useKelly;
   
   // Volatility adjustment
   double m_atrMultiplier;
   double m_currentVolatility;
   
   // Equity curve
   double m_startingEquity;
   double m_peakEquity;
   double m_currentDrawdown;
   double m_maxDrawdownPercent;
   
public:
   CRiskManager();
   ~CRiskManager();
   
   // Initialization
   bool Init(double baseRisk = 1.0, double maxRisk = 2.0, double minRisk = 0.5);
   
   // Risk calculation
   double CalculatePositionSize(string symbol, double entryPrice, double stopLoss, double confidence = 1.0);
   double CalculateLotSize(string symbol, double riskAmount, double stopLossPips);
   double GetAdaptiveRisk(double winRate, double profitFactor, double confidence);
   
   // Kelly Criterion
   double CalculateKellyFraction(double winRate, double avgWin, double avgLoss);
   void EnableKelly(bool enable, double fraction = 0.25);
   
   // Drawdown management
   bool CheckDrawdownLimit();
   void UpdateEquityCurve();
   double GetCurrentDrawdown();
   
   // Daily/Weekly limits
   bool CanTrade();
   void RegisterTrade(double profit);
   void ResetDailyCounters();
   void ResetWeeklyCounters();
   
   // Volatility adjustment
   void UpdateVolatility(double atr, double price);
   double GetVolatilityMultiplier();
   
   // Setters
   void SetMaxDailyLoss(double percent) { m_maxDailyLoss = percent; }
   void SetMaxWeeklyLoss(double percent) { m_maxWeeklyLoss = percent; }
   void SetMaxPositions(int max) { m_maxPositions = max; }
   void SetMaxDailyTrades(int max) { m_maxDailyTrades = max; }
   void SetMaxDrawdown(double percent) { m_maxDrawdownPercent = percent; }
   
   // Getters
   double GetCurrentRisk() { return m_currentRiskPercent; }
   double GetDailyLoss() { return m_dailyLoss; }
   double GetWeeklyLoss() { return m_weeklyLoss; }
   int GetDailyTradeCount() { return m_dailyTradeCount; }
   double GetDrawdownPercent() { return m_currentDrawdown; }
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CRiskManager::CRiskManager()
{
   m_baseRiskPercent = 1.0;
   m_maxRiskPercent = 2.0;
   m_minRiskPercent = 0.5;
   m_currentRiskPercent = 1.0;
   
   m_maxDailyLoss = 3.0;
   m_maxWeeklyLoss = 6.0;
   m_dailyLoss = 0.0;
   m_weeklyLoss = 0.0;
   
   m_maxPositions = 3;
   m_maxDailyTrades = 5;
   m_dailyTradeCount = 0;
   
   m_kellyFraction = 0.25;
   m_useKelly = false;
   
   m_atrMultiplier = 1.0;
   m_currentVolatility = 0.0;
   
   m_startingEquity = m_account.Balance();
   m_peakEquity = m_startingEquity;
   m_currentDrawdown = 0.0;
   m_maxDrawdownPercent = 20.0;
   
   m_lastDayReset = TimeCurrent();
   m_lastWeekReset = TimeCurrent();
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CRiskManager::~CRiskManager()
{
}

//+------------------------------------------------------------------+
//| Initialize risk manager                                           |
//+------------------------------------------------------------------+
bool CRiskManager::Init(double baseRisk = 1.0, double maxRisk = 2.0, double minRisk = 0.5)
{
   m_baseRiskPercent = baseRisk;
   m_maxRiskPercent = maxRisk;
   m_minRiskPercent = minRisk;
   m_currentRiskPercent = baseRisk;
   
   m_startingEquity = m_account.Balance();
   m_peakEquity = m_startingEquity;
   
   return true;
}

//+------------------------------------------------------------------+
//| Calculate position size                                           |
//+------------------------------------------------------------------+
double CRiskManager::CalculatePositionSize(string symbol, double entryPrice, double stopLoss, double confidence = 1.0)
{
   if(entryPrice <= 0 || stopLoss <= 0 || entryPrice == stopLoss)
      return 0.0;
   
   double balance = m_account.Balance();
   double riskAmount = balance * (m_currentRiskPercent / 100.0) * confidence;
   
   // Calculate stop loss in pips
   double stopLossPips = MathAbs(entryPrice - stopLoss) / SymbolInfoDouble(symbol, SYMBOL_POINT);
   stopLossPips /= 10.0; // Convert to standard pips
   
   // Calculate lot size
   double lotSize = CalculateLotSize(symbol, riskAmount, stopLossPips);
   
   // Apply volume limits
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   
   lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
   lotSize = MathFloor(lotSize / lotStep) * lotStep;
   
   return lotSize;
}

//+------------------------------------------------------------------+
//| Calculate lot size from risk amount                               |
//+------------------------------------------------------------------+
double CRiskManager::CalculateLotSize(string symbol, double riskAmount, double stopLossPips)
{
   if(stopLossPips <= 0)
      return 0.0;
   
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   
   // Calculate pip value for 1 lot
   double pipValue = tickValue * (point * 10) / tickSize;
   
   // Calculate lot size
   double lotSize = riskAmount / (stopLossPips * pipValue);
   
   return lotSize;
}

//+------------------------------------------------------------------+
//| Get adaptive risk based on performance                            |
//+------------------------------------------------------------------+
double CRiskManager::GetAdaptiveRisk(double winRate, double profitFactor, double confidence)
{
   double adaptiveRisk = m_baseRiskPercent;
   
   // Adjust based on win rate
   if(winRate > 0.6)
      adaptiveRisk *= 1.2;
   else if(winRate < 0.4)
      adaptiveRisk *= 0.6;
   
   // Adjust based on profit factor
   if(profitFactor > 1.5)
      adaptiveRisk *= 1.1;
   else if(profitFactor < 0.8)
      adaptiveRisk *= 0.7;
   
   // Adjust based on confidence
   adaptiveRisk *= (0.7 + confidence * 0.3);
   
   // Adjust based on current drawdown
   if(m_currentDrawdown > 10.0)
      adaptiveRisk *= 0.5;
   else if(m_currentDrawdown > 5.0)
      adaptiveRisk *= 0.75;
   
   // Apply limits
   adaptiveRisk = MathMax(m_minRiskPercent, MathMin(m_maxRiskPercent, adaptiveRisk));
   
   m_currentRiskPercent = adaptiveRisk;
   return adaptiveRisk;
}

//+------------------------------------------------------------------+
//| Calculate Kelly Criterion fraction                                |
//+------------------------------------------------------------------+
double CRiskManager::CalculateKellyFraction(double winRate, double avgWin, double avgLoss)
{
   if(avgLoss <= 0 || winRate <= 0 || winRate >= 1)
      return 0.25;
   
   double winLossRatio = avgWin / avgLoss;
   double kelly = (winRate * winLossRatio - (1 - winRate)) / winLossRatio;
   
   // Use fractional Kelly for safety
   kelly *= m_kellyFraction;
   
   // Limit to reasonable range
   return MathMax(0.1, MathMin(0.5, kelly));
}

//+------------------------------------------------------------------+
//| Enable Kelly Criterion                                            |
//+------------------------------------------------------------------+
void CRiskManager::EnableKelly(bool enable, double fraction = 0.25)
{
   m_useKelly = enable;
   m_kellyFraction = fraction;
}

//+------------------------------------------------------------------+
//| Check drawdown limit                                              |
//+------------------------------------------------------------------+
bool CRiskManager::CheckDrawdownLimit()
{
   UpdateEquityCurve();
   
   if(m_currentDrawdown >= m_maxDrawdownPercent)
   {
      Print("Maximum drawdown reached: ", m_currentDrawdown, "%");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Update equity curve                                               |
//+------------------------------------------------------------------+
void CRiskManager::UpdateEquityCurve()
{
   double currentEquity = m_account.Equity();
   
   // Update peak equity
   if(currentEquity > m_peakEquity)
      m_peakEquity = currentEquity;
   
   // Calculate current drawdown
   if(m_peakEquity > 0)
      m_currentDrawdown = ((m_peakEquity - currentEquity) / m_peakEquity) * 100.0;
   else
      m_currentDrawdown = 0.0;
}

//+------------------------------------------------------------------+
//| Get current drawdown                                              |
//+------------------------------------------------------------------+
double CRiskManager::GetCurrentDrawdown()
{
   UpdateEquityCurve();
   return m_currentDrawdown;
}

//+------------------------------------------------------------------+
//| Check if can trade                                                |
//+------------------------------------------------------------------+
bool CRiskManager::CanTrade()
{
   // Check daily reset
   datetime currentTime = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(currentTime, dt);
   
   MqlDateTime lastDayDt;
   TimeToStruct(m_lastDayReset, lastDayDt);
   
   if(dt.day != lastDayDt.day)
      ResetDailyCounters();
   
   // Check weekly reset
   if(dt.day_of_week < lastDayDt.day_of_week)
      ResetWeeklyCounters();
   
   // Check daily loss limit
   if(m_dailyLoss >= m_maxDailyLoss)
   {
      Print("Daily loss limit reached: ", m_dailyLoss, "%");
      return false;
   }
   
   // Check weekly loss limit
   if(m_weeklyLoss >= m_maxWeeklyLoss)
   {
      Print("Weekly loss limit reached: ", m_weeklyLoss, "%");
      return false;
   }
   
   // Check daily trade limit
   if(m_dailyTradeCount >= m_maxDailyTrades)
   {
      Print("Daily trade limit reached: ", m_dailyTradeCount);
      return false;
   }
   
   // Check drawdown limit
   if(!CheckDrawdownLimit())
      return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| Register trade                                                    |
//+------------------------------------------------------------------+
void CRiskManager::RegisterTrade(double profit)
{
   m_dailyTradeCount++;
   
   double balance = m_account.Balance();
   double profitPercent = (profit / balance) * 100.0;
   
   if(profit < 0)
   {
      m_dailyLoss += MathAbs(profitPercent);
      m_weeklyLoss += MathAbs(profitPercent);
   }
   
   UpdateEquityCurve();
}

//+------------------------------------------------------------------+
//| Reset daily counters                                              |
//+------------------------------------------------------------------+
void CRiskManager::ResetDailyCounters()
{
   m_dailyLoss = 0.0;
   m_dailyTradeCount = 0;
   m_lastDayReset = TimeCurrent();
   
   Print("Daily counters reset");
}

//+------------------------------------------------------------------+
//| Reset weekly counters                                             |
//+------------------------------------------------------------------+
void CRiskManager::ResetWeeklyCounters()
{
   m_weeklyLoss = 0.0;
   m_lastWeekReset = TimeCurrent();
   
   Print("Weekly counters reset");
}

//+------------------------------------------------------------------+
//| Update volatility                                                 |
//+------------------------------------------------------------------+
void CRiskManager::UpdateVolatility(double atr, double price)
{
   if(price > 0)
      m_currentVolatility = (atr / price) * 100.0;
}

//+------------------------------------------------------------------+
//| Get volatility multiplier                                         |
//+------------------------------------------------------------------+
double CRiskManager::GetVolatilityMultiplier()
{
   // Reduce position size in high volatility
   if(m_currentVolatility > 2.0)
      return 0.7;
   else if(m_currentVolatility > 1.5)
      return 0.85;
   else if(m_currentVolatility < 0.5)
      return 1.15;
   
   return 1.0;
}
//+------------------------------------------------------------------+
