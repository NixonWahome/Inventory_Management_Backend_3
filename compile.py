import pandas as pd
import pickle
from sklearn.metrics import mean_squared_error, r2_score
#Ensure you have the .pkl file
def calc_accuracy(actual, predicted):
    if actual == 0:
        return 100 if predicted == 0 else 0
    else:
        return max(0, (1 - abs(actual - predicted) / actual)) * 100

def generate_and_cache_forecast_results():
    csv_path = r"C:\Users\Overkill\Desktop\retail_store_inventory.csv"
    df = pd.read_csv(csv_path)
    # Preserve reference columns for display purposes
    df_reference = df[['Product ID', 'Category', 'Units Sold']].copy()
    
    # Convert 'Date' to datetime and extract features
    df['Date'] = pd.to_datetime(df['Date'], errors='coerce')
    df = df.dropna(subset=['Date'])
    df['Year'] = df['Date'].dt.year
    df['Month'] = df['Date'].dt.month
    df['Day'] = df['Date'].dt.day

    # Define columns
    numeric_cols = ['Inventory Level', 'Units Sold', 'Units Ordered', 'Demand Forecast', 'Price', 'Discount', 'Competitor Pricing']
    categorical_cols = ['Store ID', 'Product ID', 'Category', 'Region', 'Weather Condition', 'Holiday/Promotion', 'Seasonality']

    # Fill missing values
    for col in numeric_cols:
        if col in df.columns:
            df[col].fillna(df[col].median(), inplace=True)
    for col in categorical_cols:
        if col in df.columns:
            mode_val = df[col].mode()[0] if not df[col].mode().empty else 'Unknown'
            df[col].fillna(mode_val, inplace=True)
    df.fillna(method='ffill', inplace=True)

    # One-hot encode categorical variables, excluding 'Product ID' and 'Category'
    categorical_to_encode = [col for col in categorical_cols if col not in ['Product ID', 'Category']]
    df_encoded = pd.get_dummies(df, columns=categorical_to_encode, drop_first=True)
    
    # Drop the original 'Date' column
    df_model = df_encoded.drop(columns=['Date'])

    # Prepare features and target
    target = 'Units Sold'
    features_to_drop = [target, 'Product ID', 'Category']
    X = df_model.drop(columns=features_to_drop)
    y = df_model[target]

    # Load the trained model from forecast_model.pkl
    with open('forecast_model.pkl', 'rb') as f:
        model = pickle.load(f)

    # Make predictions
    predictions = model.predict(X)

    # Build results DataFrame
    results = pd.DataFrame({
        'Product ID': df_reference['Product ID'],
        'Category': df_reference['Category'],
        'Actual Units Sold': y,
        'Predicted Units Sold': predictions
    })
    results['Accuracy (%)'] = results.apply(lambda row: calc_accuracy(row['Actual Units Sold'], row['Predicted Units Sold']), axis=1)

    # Compute overall metrics
    overall_mse = mean_squared_error(y, predictions)
    overall_r2 = r2_score(y, predictions)

    # Cache all data in one dictionary
    cached_data = {
        'overall_mse': overall_mse,
        'overall_r2': overall_r2,
        'forecast_results': results.to_dict(orient='records')
    }
    
    # Save to a .pkl file
    with open('forecast_results.pkl', 'wb') as rf:
        pickle.dump(cached_data, rf)
    print("Forecast results and metrics cached in forecast_results.pkl")

if __name__ == '__main__':
    generate_and_cache_forecast_results()
