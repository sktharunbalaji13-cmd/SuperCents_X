//+------------------------------------------------------------------+
//|                                                SmartMoneyEA_X    |
//|                                                  Dashboard.mqh   |
//|                                       On-Chart Dashboard Display |
//+------------------------------------------------------------------+
#property copyright "SmartMoneyEA_X"
#property link      ""
#property version   "1.00"

//+------------------------------------------------------------------+
//| Includes                                                         |
//+------------------------------------------------------------------+
#include "..\Utils\Logger.mqh"
#include "..\Utils\Constants.mqh"
#include "..\Utils\Helpers.mqh"

//+------------------------------------------------------------------+
//| CLASS: Dashboard                                                 |
//| Purpose: Renders and manages the on-chart information dashboard.  |
//|          Displays current state, signals, and performance data.  |
//+------------------------------------------------------------------+
class Dashboard
{
private:
   Logger            m_logger;           // Module logger
   bool              m_initialized;      // Initialization flag
   bool              m_visible;          // Dashboard visibility

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   Dashboard()
   {
      m_logger = Logger("Dashboard");
      m_initialized = false;
      m_visible = false;
   }

   //+------------------------------------------------------------------+
   //| Destructor - removes dashboard objects                           |
   //+------------------------------------------------------------------+
   ~Dashboard()
   {
      Hide();
   }

   //+------------------------------------------------------------------+
   //| Initialize the dashboard                                         |
   //| Returns true on success                                          |
   //+------------------------------------------------------------------+
    bool Init()
    {
       m_logger.Debug("Dashboard initialized");
       m_initialized = true;
       return true;
    }

   //+------------------------------------------------------------------+
   //| Show the dashboard on the chart                                  |
   //+------------------------------------------------------------------+
   void Show()
   {
      if(!m_initialized)
         return;

      m_visible = true;
      // Future: Draw labels and objects on chart
   }

   //+------------------------------------------------------------------+
   //| Hide and remove the dashboard from the chart                     |
   //+------------------------------------------------------------------+
   void Hide()
   {
      if(!m_visible)
         return;

      Helpers::DeleteObjectsByPrefix(SMA_OBJ_DB);
      m_visible = false;
   }

   //+------------------------------------------------------------------+
   //| Refresh the dashboard display                                    |
   //+------------------------------------------------------------------+
   void Refresh()
   {
      if(!m_visible)
         return;
      // Future: Update displayed values
   }

   //+------------------------------------------------------------------+
   //| Returns whether the dashboard is initialized                     |
   //+------------------------------------------------------------------+
   bool IsInitialized()
   {
      return m_initialized;
   }
};
//+------------------------------------------------------------------+
