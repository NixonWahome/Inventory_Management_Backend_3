import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.linear_model import LinearRegression
from sklearn.metrics import mean_squared_error, r2_score
import pickle

# 1. Read the CSV file
df = pd.read_csv(r"C:\Users\Overkill\Desktop\retail_store_inventory.csv")
print("Initial columns:", df.columns.tolist())
print(df.head())

# Reset index to preserve row order
df.reset_index(drop=True, inplace=True)

# Preserve reference columns for later display: Product ID, Category, and actual Units Sold
df_reference = df[['Product ID', 'Category', 'Units Sold']].copy()

# 2. Convert 'Date' to datetime and extract features
df['Date'] = pd.to_datetime(df['Date'], errors='coerce')
df = df.dropna(subset=['Date'])  # Drop rows with invalid dates
df['Year'] = df['Date'].dt.year
df['Month'] = df['Date'].dt.month
df['Day'] = df['Date'].dt.day

# 3. Define columns
# Numeric columns (only truly numeric ones)
numeric_cols = ['Inventory Level', 'Units Sold', 'Units Ordered', 'Demand Forecast', 'Price', 'Discount', 'Competitor Pricing']
# Categorical columns – we keep Category (for display) and others for encoding.
categorical_cols = ['Store ID', 'Category', 'Region', 'Weather Condition', 'Holiday/Promotion', 'Seasonality']

# 4. Fill missing values
# For numeric columns, fill NaNs with the median
for col in numeric_cols:
    if col in df.columns:
        df[col].fillna(df[col].median(), inplace=True)

# For categorical columns, fill NaNs with the mode
for col in categorical_cols:
    if col in df.columns:
        df[col].fillna(df[col].mode()[0] if not df[col].mode().empty else 'Unknown', inplace=True)

# Optionally, forward-fill any remaining missing values
df.fillna(method='ffill', inplace=True)

# 5. One-hot encode categorical variables for modeling.
# We want to keep 'Category' for display, so we exclude it from encoding.
categorical_cols_for_encoding = [col for col in categorical_cols if col != 'Category']
df_encoded = pd.get_dummies(df, columns=categorical_cols_for_encoding, drop_first=True)

# 6. Drop columns not needed for modeling.
# Drop the original 'Date' since we've extracted Year, Month, and Day.
df_model = df_encoded.drop(columns=['Date'])

print("Final DataFrame shape:", df_model.shape)
print(df_model.head())

# 7. Feature Selection & Target Definition
# We use "Units Sold" as the target.
target = 'Units Sold'
if target not in df_model.columns:
    raise ValueError("Target column not found in the DataFrame.")

# For modeling, drop the target, Product ID, and Category (we keep Category for later reference)
features_to_drop = ['Units Sold', 'Product ID', 'Category']
X = df_model.drop(columns=features_to_drop)
y = df_model[target]

# 8. Split the data into training and testing sets.
# Also return the original indices to later reference Product ID and Category.
X_train, X_test, y_train, y_test, indices_train, indices_test = train_test_split(
    X, y, df.index, test_size=0.2, random_state=42
)

# 9. Train a Linear Regression model.
model = LinearRegression()
model.fit(X_train, y_train)

# 10. Make predictions on both training and testing sets.
train_preds = model.predict(X_train)
test_preds = model.predict(X_test)

# 11. Calculate overall accuracy metrics.
train_mse = mean_squared_error(y_train, train_preds)
train_r2 = r2_score(y_train, train_preds)
test_mse = mean_squared_error(y_test, test_preds)
test_r2 = r2_score(y_test, test_preds)
print("\n--- Overall Model Accuracy ---")
print("Training MSE:", train_mse, "Training R^2:", train_r2)
print("Testing MSE:", test_mse, "Testing R^2:", test_r2)

# 12. Prepare results for each product in the test set.
# Retrieve reference data for test indices.
df_test_reference = df_reference.loc[indices_test].reset_index(drop=True)
results = pd.DataFrame({
    'Product ID': df_test_reference['Product ID'],
    'Category': df_test_reference['Category'],
    'Actual Units Sold': y_test.reset_index(drop=True),
    'Predicted Units Sold': test_preds
})

# 13. Compute a simple accuracy metric for each record.
# Here, we define accuracy as:
#   If actual > 0: accuracy (%) = max(0, (1 - abs(actual - predicted)/actual)) * 100
#   If actual == 0: accuracy = 100 if predicted is also 0, else 0.
def calc_accuracy(actual, predicted):
    if actual == 0:
        return 100 if predicted == 0 else 0
    else:
        return max(0, (1 - abs(actual - predicted) / actual)) * 100

results['Accuracy (%)'] = results.apply(lambda row: calc_accuracy(row['Actual Units Sold'], row['Predicted Units Sold']), axis=1)

print("\n--- Prediction Results for All Products (Test Set) ---")
print(results)

# 14. Save the trained model to a .pkl file.
with open('forecast_model.pkl', 'wb') as f:
    pickle.dump(model, f)
print("\nModel training complete and saved as forecast_model.pkl")
