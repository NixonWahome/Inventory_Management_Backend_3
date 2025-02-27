from flask import Flask, request, jsonify
from flask_sqlalchemy import SQLAlchemy
from flask_jwt_extended import JWTManager, create_access_token, jwt_required, get_jwt_identity
from flask_cors import CORS
import sys
import os
import logging
from werkzeug.security import generate_password_hash, check_password_hash
from datetime import timedelta
import pandas as pd
import numpy as np
from flask import Flask, jsonify
from flask_jwt_extended import jwt_required
import pickle
from sklearn.metrics import mean_squared_error, r2_score

app = Flask(__name__)
CORS(app)

# ✅ Force logging to show everything
logging.basicConfig(
    level=logging.DEBUG,
    format="%(asctime)s - %(levelname)s - %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)]
)

# ✅ Database Configuration
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///inventory.db'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
app.config['JWT_SECRET_KEY'] = 'your_secret_key'  # Change this to a strong key
app.config['JWT_ACCESS_TOKEN_EXPIRES'] = timedelta(days=1)

db = SQLAlchemy(app)
jwt = JWTManager(app)

# ✅ User Model
class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    email = db.Column(db.String(120), unique=True, nullable=False)
    password = db.Column(db.String(255), nullable=False)

# ✅ Inventory Model
class Inventory(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    item_name = db.Column(db.String(100), nullable=False)
    quantity = db.Column(db.Integer, nullable=False)
    price = db.Column(db.Float, nullable=False)
    image_url = db.Column(db.String(255), nullable=True)

# ✅ Initialize the database
with app.app_context():
    db.create_all()

RESULTS_FILE = 'forecast_results.pkl'
# ✅ Route: Test Logging
@app.route('/test-log')
def test_log():
    logging.debug("✅ Debug log inside /test-log")
    logging.info("ℹ️ Info log inside /test-log")
    print("📢 Print statement inside /test-log")
    return "Check the logs!"

# ✅ Route: User Registration
@app.route('/register', methods=['POST'])
def register():
    data = request.json

    if User.query.filter_by(email=data['email']).first():
        return jsonify({'message': 'User already exists'}), 400

    hashed_password = generate_password_hash(data['password'], method='pbkdf2:sha256')

    new_user = User(email=data['email'], password=hashed_password)
    db.session.add(new_user)
    db.session.commit()
    
    return jsonify({'message': 'User registered successfully'}), 201

# ✅ Route: User Login
@app.route('/login', methods=['POST'])
def login():
    data = request.json
    user = User.query.filter_by(email=data['email']).first()

    if not user:
        return jsonify({'message': 'User not found'}), 401

    if not check_password_hash(user.password, data['password']):
        return jsonify({'message': 'Incorrect password'}), 401

    # Convert user.id to a string
    access_token = create_access_token(identity=str(user.id))
    return jsonify({'token': access_token}), 200


# ✅ Route: Add Inventory Item
@app.route('/inventory', methods=['POST'])
@jwt_required()
def add_item():
    logging.debug("🔹 Received request to add inventory item")
    current_user = get_jwt_identity()  # Logs the user ID from the token
    logging.debug(f"🔹 JWT Identity: {current_user}")

    logging.debug(f"🔹 Headers: {request.headers}")
    logging.debug(f"🔹 Raw Request Body: {request.data}")

    try:
        data = request.get_json()
        logging.debug(f"🔹 Parsed JSON Data: {data}")
    except Exception as e:
        logging.error(f"❌ ERROR: Failed to parse JSON - {str(e)}")
        return jsonify({'error': 'Invalid JSON format'}), 400

    if not data:
        logging.error("❌ ERROR: No data provided")
        return jsonify({'error': 'Invalid request, no data provided'}), 422

    required_fields = ['item_name', 'quantity', 'price']
    for field in required_fields:
        if field not in data:
            logging.error(f"❌ ERROR: Missing required field -> {field}")
            return jsonify({'error': f'Missing required field: {field}'}), 422

    # Create and add the new inventory item
    new_item = Inventory(
        item_name=data['item_name'],
        quantity=data['quantity'],
        price=data['price'],
        image_url=data.get('image_url')  # This will be None if not provided
    )
    logging.debug(f"🔹 Adding new inventory item to database: {new_item}")

    db.session.add(new_item)
    db.session.commit()

    logging.info("✅ Item added successfully")
    return jsonify({"message": "Item added successfully", "data": data}), 201



# ✅ Route: Get Inventory Items
@app.route('/inventory', methods=['GET'])
@jwt_required()
def get_inventory():
    items = Inventory.query.all()
    inventory_list = [
        {
            'id': item.id, 
            'item_name': item.item_name, 
            'quantity': item.quantity, 
            'price': item.price,
            'image_url': item.image_url
        } 
        for item in items
    ]
    
    return jsonify(inventory_list), 200

# ✅ Route: Update Inventory Item
@app.route('/inventory/<int:item_id>', methods=['PUT'])
@jwt_required()
def update_item(item_id):
    data = request.json
    item = Inventory.query.get(item_id)

    if not item:
        return jsonify({'message': 'Item not found'}), 404

    item.item_name = data.get('item_name', item.item_name)
    item.quantity = data.get('quantity', item.quantity)
    item.price = data.get('price', item.price)
    item.image_url = data.get('image_url', item.image_url)

    db.session.commit()
    return jsonify({'message': 'Item updated successfully'}), 200

# ✅ Route: Delete Inventory Item
@app.route('/inventory/<int:item_id>', methods=['DELETE'])
@jwt_required()
def delete_item(item_id):
    item = Inventory.query.get(item_id)

    if not item:
        return jsonify({'message': 'Item not found'}), 404

    db.session.delete(item)
    db.session.commit()
    return jsonify({'message': 'Item deleted successfully'}), 200



@app.route('/forecast-results', methods=['GET'])
@jwt_required()
def forecast_results():
    if os.path.exists(RESULTS_FILE):
        try:
            with open(RESULTS_FILE, 'rb') as rf:
                cached_data = pickle.load(rf)
            
            # Determine the data format
            if isinstance(cached_data, dict):
                overall_mse = cached_data.get('overall_mse', 0.0)
                overall_r2 = cached_data.get('overall_r2', 0.0)
                results_list = cached_data.get('forecast_results', [])
            elif isinstance(cached_data, list):
                overall_mse = 0.0
                overall_r2 = 0.0
                results_list = cached_data
            else:
                overall_mse = 0.0
                overall_r2 = 0.0
                results_list = []
            
            # Pagination parameters
            page = request.args.get('page', default=1, type=int)
            per_page = request.args.get('per_page', default=20, type=int)
            total_results = len(results_list)
            start = (page - 1) * per_page
            end = start + per_page
            paginated_results = results_list[start:end]
            
            return jsonify({
                'overall_mse': overall_mse,
                'overall_r2': overall_r2,
                'page': page,
                'per_page': per_page,
                'total_results': total_results,
                'forecast_results': paginated_results
            }), 200

        except Exception as e:
            return jsonify({'error': f'Error loading forecast results: {str(e)}'}), 500
    else:
        return jsonify({'error': 'Precomputed forecast results not found.'}), 404

# ✅ Run the app in debug mode
if __name__ == '__main__':
    app.run(debug=True)
