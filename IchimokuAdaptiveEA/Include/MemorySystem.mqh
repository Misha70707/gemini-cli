//+------------------------------------------------------------------+
//|                                                 MemorySystem.mqh |
//|                                    Advanced Memory & Learning    |
//+------------------------------------------------------------------+
#property copyright "Ichimoku Adaptive EA"
#property link      ""
#property version   "1.00"

//+------------------------------------------------------------------+
//| Trade Memory Structure                                            |
//+------------------------------------------------------------------+
struct TradeMemory
{
   datetime time;
   double entryPrice;
   double exitPrice;
   double profit;
   double riskReward;
   int trendStrength;
   double volatility;
   bool wasWinner;
   int cloudPosition;      // 1=above, -1=below, 0=inside
   double tkCrossStrength;
   int holdingPeriod;
};

//+------------------------------------------------------------------+
//| Pattern Recognition Structure                                     |
//+------------------------------------------------------------------+
struct MarketPattern
{
   int patternType;        // 1=strong trend, 2=ranging, 3=reversal
   double successRate;
   int occurrences;
   double avgProfit;
   double avgLoss;
   double volatilityLevel;
};

//+------------------------------------------------------------------+
//| Memory System Class                                               |
//+------------------------------------------------------------------+
class CMemorySystem
{
private:
   TradeMemory m_tradeHistory[];
   MarketPattern m_patterns[];
   int m_maxMemorySize;
   int m_currentMemoryIndex;
   
   // Performance metrics
   double m_recentWinRate;
   double m_recentProfitFactor;
   double m_adaptiveConfidence;
   
   // Learning parameters
   double m_learningRate;
   int m_lookbackPeriod;
   
public:
   CMemorySystem();
   ~CMemorySystem();
   
   // Initialization
   bool Init(int maxSize = 1000, double learningRate = 0.1);
   
   // Memory management
   void AddTrade(TradeMemory &trade);
   void UpdatePatterns();
   
   // Analysis methods
   double GetWinRate(int lookback = 50);
   double GetProfitFactor(int lookback = 50);
   double GetAverageRR(int lookback = 50);
   double GetConfidenceScore();
   
   // Pattern recognition
   int IdentifyCurrentPattern(double volatility, int trendStrength);
   double GetPatternSuccessRate(int patternType);
   
   // Adaptive learning
   double GetAdaptiveRiskMultiplier();
   double GetAdaptivePositionMultiplier();
   bool ShouldTrade(int currentPattern);
   
   // Getters
   double GetRecentWinRate() { return m_recentWinRate; }
   double GetConfidence() { return m_adaptiveConfidence; }
   int GetTradeCount() { return ArraySize(m_tradeHistory); }
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CMemorySystem::CMemorySystem()
{
   m_maxMemorySize = 1000;
   m_currentMemoryIndex = 0;
   m_recentWinRate = 0.5;
   m_recentProfitFactor = 1.0;
   m_adaptiveConfidence = 0.5;
   m_learningRate = 0.1;
   m_lookbackPeriod = 50;
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CMemorySystem::~CMemorySystem()
{
   ArrayFree(m_tradeHistory);
   ArrayFree(m_patterns);
}

//+------------------------------------------------------------------+
//| Initialize memory system                                          |
//+------------------------------------------------------------------+
bool CMemorySystem::Init(int maxSize = 1000, double learningRate = 0.1)
{
   m_maxMemorySize = maxSize;
   m_learningRate = learningRate;
   
   ArrayResize(m_tradeHistory, 0);
   ArrayResize(m_patterns, 10);
   
   // Initialize pattern structures
   for(int i = 0; i < 10; i++)
   {
      m_patterns[i].patternType = i;
      m_patterns[i].successRate = 0.5;
      m_patterns[i].occurrences = 0;
      m_patterns[i].avgProfit = 0.0;
      m_patterns[i].avgLoss = 0.0;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Add trade to memory                                               |
//+------------------------------------------------------------------+
void CMemorySystem::AddTrade(TradeMemory &trade)
{
   int size = ArraySize(m_tradeHistory);
   
   if(size >= m_maxMemorySize)
   {
      // Remove oldest trade (FIFO)
      for(int i = 0; i < size - 1; i++)
         m_tradeHistory[i] = m_tradeHistory[i + 1];
      
      m_tradeHistory[size - 1] = trade;
   }
   else
   {
      ArrayResize(m_tradeHistory, size + 1);
      m_tradeHistory[size] = trade;
   }
   
   // Update patterns after adding trade
   UpdatePatterns();
}

//+------------------------------------------------------------------+
//| Update pattern recognition                                        |
//+------------------------------------------------------------------+
void CMemorySystem::UpdatePatterns()
{
   int size = ArraySize(m_tradeHistory);
   if(size < 10) return;
   
   // Calculate recent performance
   m_recentWinRate = GetWinRate(m_lookbackPeriod);
   m_recentProfitFactor = GetProfitFactor(m_lookbackPeriod);
   
   // Update confidence based on consistency
   double consistency = 0.0;
   int lookback = MathMin(20, size);
   
   for(int i = size - lookback; i < size; i++)
   {
      if(m_tradeHistory[i].wasWinner)
         consistency += 1.0;
   }
   
   consistency /= lookback;
   
   // Adaptive confidence calculation
   m_adaptiveConfidence = (m_recentWinRate * 0.4) + 
                          (MathMin(m_recentProfitFactor / 2.0, 1.0) * 0.3) +
                          (consistency * 0.3);
}

//+------------------------------------------------------------------+
//| Get win rate                                                      |
//+------------------------------------------------------------------+
double CMemorySystem::GetWinRate(int lookback = 50)
{
   int size = ArraySize(m_tradeHistory);
   if(size == 0) return 0.5;
   
   int start = MathMax(0, size - lookback);
   int winners = 0;
   int total = 0;
   
   for(int i = start; i < size; i++)
   {
      if(m_tradeHistory[i].profit > 0)
         winners++;
      total++;
   }
   
   return total > 0 ? (double)winners / total : 0.5;
}

//+------------------------------------------------------------------+
//| Get profit factor                                                 |
//+------------------------------------------------------------------+
double CMemorySystem::GetProfitFactor(int lookback = 50)
{
   int size = ArraySize(m_tradeHistory);
   if(size == 0) return 1.0;
   
   int start = MathMax(0, size - lookback);
   double grossProfit = 0.0;
   double grossLoss = 0.0;
   
   for(int i = start; i < size; i++)
   {
      if(m_tradeHistory[i].profit > 0)
         grossProfit += m_tradeHistory[i].profit;
      else
         grossLoss += MathAbs(m_tradeHistory[i].profit);
   }
   
   return grossLoss > 0 ? grossProfit / grossLoss : 1.0;
}

//+------------------------------------------------------------------+
//| Get average risk/reward ratio                                     |
//+------------------------------------------------------------------+
double CMemorySystem::GetAverageRR(int lookback = 50)
{
   int size = ArraySize(m_tradeHistory);
   if(size == 0) return 1.5;
   
   int start = MathMax(0, size - lookback);
   double totalRR = 0.0;
   int count = 0;
   
   for(int i = start; i < size; i++)
   {
      if(m_tradeHistory[i].riskReward > 0)
      {
         totalRR += m_tradeHistory[i].riskReward;
         count++;
      }
   }
   
   return count > 0 ? totalRR / count : 1.5;
}

//+------------------------------------------------------------------+
//| Get confidence score                                              |
//+------------------------------------------------------------------+
double CMemorySystem::GetConfidenceScore()
{
   return m_adaptiveConfidence;
}

//+------------------------------------------------------------------+
//| Identify current market pattern                                   |
//+------------------------------------------------------------------+
int CMemorySystem::IdentifyCurrentPattern(double volatility, int trendStrength)
{
   // Pattern classification:
   // 1 = Strong uptrend
   // 2 = Strong downtrend
   // 3 = Ranging market
   // 4 = High volatility
   // 5 = Low volatility
   
   if(MathAbs(trendStrength) > 70)
      return trendStrength > 0 ? 1 : 2;
   else if(volatility > 0.02)
      return 4;
   else if(volatility < 0.005)
      return 5;
   else
      return 3;
}

//+------------------------------------------------------------------+
//| Get pattern success rate                                          |
//+------------------------------------------------------------------+
double CMemorySystem::GetPatternSuccessRate(int patternType)
{
   if(patternType < 0 || patternType >= ArraySize(m_patterns))
      return 0.5;
   
   return m_patterns[patternType].successRate;
}

//+------------------------------------------------------------------+
//| Get adaptive risk multiplier                                      |
//+------------------------------------------------------------------+
double CMemorySystem::GetAdaptiveRiskMultiplier()
{
   // Reduce risk after losses, increase after wins
   double multiplier = 1.0;
   
   if(m_recentWinRate > 0.6 && m_recentProfitFactor > 1.5)
      multiplier = 1.3;  // Increase risk when performing well
   else if(m_recentWinRate < 0.4 || m_recentProfitFactor < 0.8)
      multiplier = 0.5;  // Reduce risk when performing poorly
   else if(m_recentWinRate < 0.45)
      multiplier = 0.7;
   
   // Confidence-based adjustment
   multiplier *= (0.5 + m_adaptiveConfidence * 0.5);
   
   return MathMax(0.3, MathMin(1.5, multiplier));
}

//+------------------------------------------------------------------+
//| Get adaptive position multiplier                                  |
//+------------------------------------------------------------------+
double CMemorySystem::GetAdaptivePositionMultiplier()
{
   // Similar to risk multiplier but more conservative
   double multiplier = 1.0;
   
   if(m_recentWinRate > 0.65 && m_recentProfitFactor > 2.0)
      multiplier = 1.2;
   else if(m_recentWinRate < 0.4)
      multiplier = 0.6;
   
   return MathMax(0.5, MathMin(1.3, multiplier));
}

//+------------------------------------------------------------------+
//| Should trade based on memory                                      |
//+------------------------------------------------------------------+
bool CMemorySystem::ShouldTrade(int currentPattern)
{
   // Don't trade if confidence is too low
   if(m_adaptiveConfidence < 0.3)
      return false;
   
   // Check if we have enough data
   if(ArraySize(m_tradeHistory) < 10)
      return true;  // Allow trading with limited data
   
   // Check recent performance
   if(m_recentWinRate < 0.35 && ArraySize(m_tradeHistory) > 20)
      return false;  // Stop trading if performing very poorly
   
   return true;
}
//+------------------------------------------------------------------+
