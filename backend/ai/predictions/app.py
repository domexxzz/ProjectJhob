import uvicorn
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
from prophet import Prophet
import logging

# Configure logger
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("ai-predictions")

app = FastAPI(title="AI Financial Forecasting Service", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class TransactionItem(BaseModel):
    id: Optional[str] = None
    date: str  # YYYY-MM-DD
    amount: float  # Baht
    type: str  # income | expense
    note: Optional[str] = ""

class PredictionRequest(BaseModel):
    transactions: List[TransactionItem]
    current_balance: float  # Baht
    monthly_income: float  # Baht
    forecast_days: int = 30

class ForecastDay(BaseModel):
    date: str
    balance: float
    lower: float
    upper: float

class PredictionAlert(BaseModel):
    type: str  # info | warning | danger
    title: str
    body: str

class PredictionAnomaly(BaseModel):
    id: Optional[str] = None
    date: str
    amount: float
    note: str
    description: str

class PredictionResponse(BaseModel):
    forecast: List[ForecastDay]
    predicted_total_expense: float
    predicted_total_income: float
    projected_ending_balance: float
    alerts: List[PredictionAlert]
    anomalies: List[PredictionAnomaly]


def run_fallback_forecast(
    df_exp: pd.DataFrame, 
    df_inc: pd.DataFrame, 
    current_balance: float, 
    forecast_days: int
) -> tuple:
    """Fallback forecasting method using simple linear averages if data is insufficient for Prophet."""
    logger.info("Running simple fallback linear forecasting...")
    
    # Calculate daily averages
    avg_daily_expense = df_exp['amount'].mean() if not df_exp.empty else 0.0
    avg_daily_income = df_inc['amount'].mean() if not df_inc.empty else 0.0
    
    # If no history exists, use heuristic values
    if avg_daily_expense == 0:
        avg_daily_expense = 300.0  # Assumed default daily spending
        
    start_date = datetime.now()
    forecast_dates = [(start_date + timedelta(days=i)).strftime('%Y-%m-%d') for i in range(1, forecast_days + 1)]
    
    forecast_list = []
    running_balance = current_balance
    
    # Calculate standard deviation for confidence bounds
    std_exp = df_exp['amount'].std() if (not df_exp.empty and len(df_exp) > 1) else 100.0
    if np.isnan(std_exp):
        std_exp = 100.0
        
    for i, date_str in enumerate(forecast_dates):
        # Accumulate daily forecast
        running_balance += (avg_daily_income - avg_daily_expense)
        uncertainty = std_exp * np.sqrt(i + 1) * 0.5
        
        forecast_list.append(ForecastDay(
            date=date_str,
            balance=max(0.0, float(round(running_balance, 2))),
            lower=max(0.0, float(round(running_balance - uncertainty, 2))),
            upper=float(round(running_balance + uncertainty, 2))
        ))
        
    predicted_total_expense = avg_daily_expense * forecast_days
    predicted_total_income = avg_daily_income * forecast_days
    
    return forecast_list, predicted_total_expense, predicted_total_income


def run_prophet_forecast(
    df_exp: pd.DataFrame, 
    df_inc: pd.DataFrame, 
    current_balance: float, 
    forecast_days: int
) -> tuple:
    """Run Facebook Prophet model on daily expense and income transactions."""
    logger.info("Fitting and predicting with Prophet model...")
    
    # Standardize dataframes for Prophet
    df_exp_daily = df_exp.groupby('date')['amount'].sum().reset_index()
    df_exp_daily.columns = ['ds', 'y']
    df_exp_daily['ds'] = pd.to_datetime(df_exp_daily['ds'])
    
    # Fill date gaps with zero spending (very important for Prophet)
    if not df_exp_daily.empty:
        r = pd.date_range(start=df_exp_daily['ds'].min(), end=df_exp_daily['ds'].max())
        df_exp_daily = df_exp_daily.set_index('ds').reindex(r, fill_value=0.0).rename_axis('ds').reset_index()

    # Model expenses
    try:
        m_exp = Prophet(
            yearly_seasonality=False,
            weekly_seasonality=True,
            daily_seasonality=False,
            interval_width=0.80
        )
        m_exp.fit(df_exp_daily)
        
        future_exp = m_exp.make_future_dataframe(periods=forecast_days, include_history=False)
        forecast_exp = m_exp.predict(future_exp)
        
        # Clip negative predictions to 0
        forecast_exp['yhat'] = forecast_exp['yhat'].clip(lower=0.0)
        forecast_exp['yhat_lower'] = forecast_exp['yhat_lower'].clip(lower=0.0)
    except Exception as e:
        logger.error(f"Error fitting Prophet model for expenses: {e}. Falling back...")
        return run_fallback_forecast(df_exp, df_inc, current_balance, forecast_days)

    # Model incomes
    predicted_incomes = pd.DataFrame({'ds': forecast_exp['ds'], 'yhat': 0.0, 'yhat_lower': 0.0, 'yhat_upper': 0.0})
    if not df_inc.empty:
        df_inc_daily = df_inc.groupby('date')['amount'].sum().reset_index()
        df_inc_daily.columns = ['ds', 'y']
        df_inc_daily['ds'] = pd.to_datetime(df_inc_daily['ds'])
        
        # Fill date gaps with zero income
        r = pd.date_range(start=df_inc_daily['ds'].min(), end=df_inc_daily['ds'].max())
        df_inc_daily = df_inc_daily.set_index('ds').reindex(r, fill_value=0.0).rename_axis('ds').reset_index()
        
        try:
            m_inc = Prophet(
                yearly_seasonality=False,
                weekly_seasonality=True,
                daily_seasonality=False
            )
            m_inc.fit(df_inc_daily)
            future_inc = m_inc.make_future_dataframe(periods=forecast_days, include_history=False)
            pred_inc = m_inc.predict(future_inc)
            predicted_incomes['yhat'] = pred_inc['yhat'].clip(lower=0.0)
        except Exception as e:
            logger.error(f"Error fitting Prophet model for incomes: {e}. Defaulting to mean daily income...")
            predicted_incomes['yhat'] = df_inc['amount'].mean()

    # Reconstruct daily balances
    forecast_list = []
    running_balance = current_balance
    
    for i in range(len(forecast_exp)):
        row_exp = forecast_exp.iloc[i]
        row_inc = predicted_incomes.iloc[i]
        
        net_change = row_inc['yhat'] - row_exp['yhat']
        running_balance += net_change
        
        # Calculate uncertainty range from Prophet expense bounds
        margin = (row_exp['yhat_upper'] - row_exp['yhat_lower']) / 2.0
        uncertainty = margin * np.sqrt(i + 1)
        
        forecast_list.append(ForecastDay(
            date=row_exp['ds'].strftime('%Y-%m-%d'),
            balance=max(0.0, float(round(running_balance, 2))),
            lower=max(0.0, float(round(running_balance - uncertainty, 2))),
            upper=float(round(running_balance + uncertainty, 2))
        ))
        
    predicted_total_expense = float(round(forecast_exp['yhat'].sum(), 2))
    predicted_total_income = float(round(predicted_incomes['yhat'].sum(), 2))
    
    return forecast_list, predicted_total_expense, predicted_total_income


@app.post("/predict", response_model=PredictionResponse)
def predict_transactions(request: PredictionRequest):
    if not request.transactions:
        # Generate default empty prediction responses
        fallback_forecast, pred_exp, pred_inc = run_fallback_forecast(
            pd.DataFrame(), pd.DataFrame(), request.current_balance, request.forecast_days
        )
        return PredictionResponse(
            forecast=fallback_forecast,
            predicted_total_expense=pred_exp,
            predicted_total_income=pred_inc,
            projected_ending_balance=request.current_balance,
            alerts=[
                PredictionAlert(
                    type="info",
                    title="เริ่มสร้างบันทึกการเงิน",
                    body="บันทึกรายรับ-รายจ่ายของคุณเพื่อเริ่มใช้การวิเคราะห์และทำนายแนวโน้มกระแสเงินสดด้วย AI!"
                )
            ],
            anomalies=[]
        )

    # Convert list of items to Pandas DataFrame
    data = [t.model_dump() for t in request.transactions]
    df = pd.DataFrame(data)
    
    # Split into income and expense
    df_exp = df[df['type'] == 'expense'].copy()
    df_inc = df[df['type'] == 'income'].copy()
    
    # Calculate unique spending days
    unique_exp_days = df_exp['date'].nunique() if not df_exp.empty else 0
    
    # Run appropriate model
    if unique_exp_days < 5:
        forecast_list, predicted_total_expense, predicted_total_income = run_fallback_forecast(
            df_exp, df_inc, request.current_balance, request.forecast_days
        )
    else:
        forecast_list, predicted_total_expense, predicted_total_income = run_prophet_forecast(
            df_exp, df_inc, request.current_balance, request.forecast_days
        )
        
    projected_ending_balance = forecast_list[-1].balance if forecast_list else request.current_balance
    
    # ── AI Insights & Alerts ──────────────────────────────────────────────────
    alerts = []
    
    # Deficit check
    if predicted_total_expense > (predicted_total_income + request.current_balance):
        alerts.append(PredictionAlert(
            type="danger",
            title="ความเสี่ยงเงินตึงมือสูงมาก",
            body=f"AI คาดการณ์ว่าใน 30 วันข้างหน้า คุณจะมียอดใช้จ่ายรวมสูงถึง ฿{predicted_total_expense:,.2f} ซึ่งจะเกินกว่ารายรับรวมและเงินคงเหลือทั้งหมดที่มี!"
        ))
    elif predicted_total_expense > predicted_total_income:
        alerts.append(PredictionAlert(
            type="warning",
            title="รายจ่ายกำลังล้นเกินรายได้",
            body=f"เดือนนี้รายจ่ายคาดการณ์ (฿{predicted_total_expense:,.2f}) จะแซงหน้าเงินได้สะสมของคุณ ระมัดระวังการสร้างหนี้เพิ่มเติม"
        ))
    else:
        alerts.append(PredictionAlert(
            type="info",
            title="กระแสเงินสดสมดุลดี",
            body="วิเคราะห์แล้ว รายรับล่วงหน้าของคุณเพียงพอครอบคลุมแผนการใช้จ่ายทั้งหมด มีโอกาสออมเงินเพิ่มขึ้น!"
        ))

    # Burn out rate calculation
    if not df_exp.empty:
        total_monthly_spending = df_exp['amount'].sum()
        days_in_history = (pd.to_datetime(df_exp['date'].max()) - pd.to_datetime(df_exp['date'].min())).days + 1
        days_in_history = max(days_in_history, 1)
        avg_daily_burn = total_monthly_spending / days_in_history
        
        if avg_daily_burn > 0 and request.current_balance > 0:
            days_until_empty = request.current_balance / avg_daily_burn
            if days_until_empty < 10:
                alerts.append(PredictionAlert(
                    type="danger",
                    title="ยอดเงินคงเหลือจะหมดเร็วๆ นี้",
                    body=f"ด้วยอัตราการใช้เงินเฉลี่ยวันละ ฿{avg_daily_burn:,.2f} ยอดเงินของคุณจะหมดภายในอีก {int(days_until_empty)} วัน หากไม่มีรายได้เพิ่ม!"
                ))
            elif days_until_empty < 20:
                alerts.append(PredictionAlert(
                    type="warning",
                    title="งบประมาณจำกัดในช่วงปลายเดือน",
                    body=f"ระมัดระวัง เงินกองกลางของคุณคาดว่าจะอยู่รอดได้อีกประมาณ {int(days_until_empty)} วัน แนะนำให้ปรับลดค่าใช้จ่ายไม่จำเป็น"
                ))

    # ── Outlier / Anomaly Detection ───────────────────────────────────────────
    anomalies = []
    if not df_exp.empty and len(df_exp) >= 3:
        # Mark anomalies where expense amount is standard deviation outlier (Z-Score > 2)
        mean_exp = df_exp['amount'].mean()
        std_exp = df_exp['amount'].std()
        
        # Minimum threshold of 1,000 Baht to avoid alerting on small variations
        threshold = max(mean_exp + 2 * std_exp, 1000.0) if std_exp > 0 else 1000.0
        
        anom_rows = df_exp[df_exp['amount'] > threshold]
        for _, row in anom_rows.iterrows():
            note_str = row['note'] if (isinstance(row['note'], str) and row['note']) else "รายการทั่วไป"
            anomalies.append(PredictionAnomaly(
                id=row['id'],
                date=row['date'],
                amount=row['amount'],
                note=note_str,
                description=f"ยอดใช้จ่ายสูงผิดปกติ ฿{row['amount']:,.2f} ซึ่งสูงกว่าค่าเฉลี่ยปกติ ({mean_exp:,.2f}) มากกว่า 2 เท่า"
            ))

    return PredictionResponse(
        forecast=forecast_list,
        predicted_total_expense=predicted_total_expense,
        predicted_total_income=predicted_total_income,
        projected_ending_balance=projected_ending_balance,
        alerts=alerts,
        anomalies=anomalies[:5]  # limit to top 5 anomalies
    )


if __name__ == "__main__":
    logger.info("Starting FastAPI local prediction server...")
    uvicorn.run(app, host="127.0.0.1", port=8000)
