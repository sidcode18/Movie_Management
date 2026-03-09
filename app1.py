# app.py
from flask import Flask, jsonify, request, session, render_template, send_from_directory
import pymysql.cursors
from flask_cors import CORS
from werkzeug.security import generate_password_hash, check_password_hash
import os
import re # Import Regex for validation
import requests # Needed for external API calls

# 1. Initialize the Flask App
app = Flask(__name__, template_folder='templates', static_folder='static')

# 2. Configuration
CORS(app, supports_credentials=True) 
app.config['SECRET_KEY'] = os.urandom(32) # Your secure key

# 3. Database & API Key Configuration
DB_HOST = 'localhost'
DB_USER = 'root'
DB_PASSWORD = '' # !! MAKE SURE YOUR PASSWORD IS CORRECT !!
DB_DATABASE = 'cinematic_vault'

# --- 4. !!! ADD YOUR API KEY HERE !!! ---
# Get your free key from themoviedb.org
TMDB_API_KEY = '7ed991523702aa11924789993ed5ee7e'
TMDB_BASE_URL = 'https://api.themoviedb.org/3'

# --- 5. PAGE SERVING ROUTES ---
@app.route('/')
def route_home():
    """Serves the main index2.html (home page)."""
    return render_template('index2.html')

@app.route('/login')
def route_login():
    """Serves the login2.html page."""
    return render_template('login2.html')

@app.route('/register')
def route_register():
    """Serves the register.html page."""
    return render_template('register.html')

# --- 6. *** NEW *** ADMIN PAGE ROUTE ---
@app.route('/add_movie')
def route_add_movie():
    # Protect this page
    if 'role' not in session or session['role'] != 'admin':
        return "Access Denied. <a href='/'>Go Home</a>", 403
    return render_template('add_movie.html')

@app.route('/static/<path:filename>')
def route_static_files(filename):
    """Serves any file from the 'static' folder (CSS, JS)."""
    return send_from_directory('static', filename)

# --- 7. API ROUTE: User Registration ---
@app.route('/api/register', methods=['POST'])
def register_user():
    data = request.json
    first_name = data.get('first_name')
    last_name = data.get('last_name')
    username = data.get('username')
    password = data.get('password')
    email = data.get('email')
    mobile_no = data.get('mobile_no')
    confirm_password = data.get('confirm_password')

    if password != confirm_password:
        return jsonify({"error": "Passwords do not match"}), 400
    if not all([first_name, last_name, username, password, email]):
        return jsonify({"error": "First Name, Last Name, Username, Password, and Email are required"}), 400
    if not re.match(r"[^@]+@[^@]+\.[^@]+", email):
        return jsonify({"error": "Invalid email format"}), 400
    if mobile_no and not re.match(r"^\d{10}$", mobile_no):
         return jsonify({"error": "Invalid mobile number. Must be 10 digits."}), 400
    if not re.match(r"^(?=.*[A-Z])(?=.*[a-z])(?=.*\d).{8,}$", password):
        return jsonify({"error": "Password must be 8+ chars, with uppercase, lowercase, and a number."}), 400

    password_hash = generate_password_hash(password)    

    try:
        connection = pymysql.connect(host=DB_HOST, user=DB_USER, password=DB_PASSWORD, database=DB_DATABASE, cursorclass=pymysql.cursors.DictCursor)
        with connection.cursor() as cursor:
            cursor.execute("SELECT * FROM users WHERE username = %s OR email = %s", (username, email))
            if cursor.fetchone():
                return jsonify({"error": "Username or email already exists"}), 409
            
            sql = "INSERT INTO users (first_name, last_name, username, password_hash, email, mobile_no) VALUES (%s, %s, %s, %s, %s, %s)"
            cursor.execute(sql, (first_name, last_name, username, password_hash, email, mobile_no))
        connection.commit()
    except Exception as e:
        print("REGISTRATION ERROR:", str(e))
        return jsonify({"error": str(e)}), 500
    finally:
        connection.close()

    return jsonify({"message": "User registered successfully"}), 201

# --- 8. API ROUTE: User Login ---
@app.route('/api/login', methods=['POST'])
def login_user():
    data = request.json
    username = data.get('username')
    password = data.get('password')
    if not username or not password:
        return jsonify({"error": "Missing username or password"}), 400
    try:
        connection = pymysql.connect(host=DB_HOST, user=DB_USER, password=DB_PASSWORD, database=DB_DATABASE, cursorclass=pymysql.cursors.DictCursor)
        with connection.cursor() as cursor:
            cursor.execute("SELECT * FROM users WHERE username = %s", (username,))
            user = cursor.fetchone()
        if user and check_password_hash(user['password_hash'], password):
            session['user_id'] = user['user_id']
            session['username'] = user['username']
            session['role'] = user['role']
            return jsonify({"message": "Login successful", "username": user['username'], "role": user['role']}), 200
        else:
            return jsonify({"error": "Invalid username or password"}), 401
    except Exception as e:
        print("LOGIN ERROR:", str(e))
        return jsonify({"error": str(e)}), 500
    finally:
        if 'connection' in locals() and connection.open:
            connection.close()

# --- 9. API ROUTE: User Logout ---
@app.route('/api/logout', methods=['POST'])
def logout_user():
    session.clear() 
    return jsonify({"message": "Logout successful"}), 200

# --- 10. API ROUTE: Check Login Status ---
@app.route('/api/check_session', methods=['GET'])
def check_session():
    if 'user_id' in session:
        return jsonify({"is_logged_in": True, "user_id": session['user_id'], "username": session['username'], "role": session['role']}), 200
    else:
        return jsonify({"is_logged_in": False}), 200

# --- 11. API ROUTE: Get All Movies (PUBLIC) ---
@app.route('/api/movies', methods=['GET'])
def get_all_movies():
    user_id = session.get('user_id')
    try:
        connection = pymysql.connect(host=DB_HOST, user=DB_USER, password=DB_PASSWORD, database=DB_DATABASE, cursorclass=pymysql.cursors.DictCursor)
        with connection.cursor() as cursor:
            # This query gets avg rating and this user's personal rating
            sql = """
                SELECT 
                    m.movie_id, m.title, m.release_year, m.image_url,
                    COALESCE(AVG(ur.rating), m.rating) AS avg_rating,
                    (SELECT rating FROM user_ratings WHERE user_id = %s AND movie_id = m.movie_id) AS user_rating
                FROM movies m
                LEFT JOIN user_ratings ur ON m.movie_id = ur.movie_id
                GROUP BY m.movie_id, m.title, m.release_year, m.image_url, m.rating
            """
            cursor.execute(sql, (user_id,))
            movies = cursor.fetchall()
        connection.close()
        return jsonify(movies)
    except Exception as e:
        print("GET_ALL_MOVIES_ERROR:", str(e))
        return jsonify({"error": str(e)}), 500

# --- 12. API ROUTE: Search Movies (PUBLIC) ---
@app.route('/api/movies/search', methods=['GET'])
def search_movies():
    user_id = session.get('user_id')
    search_title = request.args.get('title')
    if not search_title:
        return jsonify({"error": "A 'title' query parameter is required."}), 400
    try:
        connection = pymysql.connect(host=DB_HOST, user=DB_USER, password=DB_PASSWORD, database=DB_DATABASE, cursorclass=pymysql.cursors.DictCursor)
        with connection.cursor() as cursor:
            query = """
                SELECT 
                    m.movie_id, m.title, m.release_year, m.image_url,
                    COALESCE(AVG(ur.rating), m.rating) AS avg_rating,
                    (SELECT rating FROM user_ratings WHERE user_id = %s AND movie_id = m.movie_id) AS user_rating
                FROM movies m
                LEFT JOIN user_ratings ur ON m.movie_id = ur.movie_id
                WHERE m.title LIKE %s
                GROUP BY m.movie_id, m.title, m.release_year, m.image_url, m.rating
            """
            search_term = f"%{search_title}%"
            cursor.execute(query, (user_id, search_term))
            movies = cursor.fetchall()
        connection.close()
        return jsonify(movies)
    except Exception as e:
        print("SEARCH_MOVIES_ERROR:", str(e))
        return jsonify({"error": str(e)}), 500

# --- 13. API ROUTE: Get Single Movie Details (COMPLEX JOIN) ---
@app.route('/api/movie_details/<int:movie_id>', methods=['GET'])
def get_movie_details(movie_id):
    user_id = session.get('user_id')
    try:
        connection = pymysql.connect(host=DB_HOST, user=DB_USER, password=DB_PASSWORD, database=DB_DATABASE, cursorclass=pymysql.cursors.DictCursor)
        with connection.cursor() as cursor:
            # 1. Get Movie Info, Studio, and Genres
            sql_movie = """
                SELECT 
                    m.*, s.studio_name,
                    GROUP_CONCAT(DISTINCT g.genre_name SEPARATOR ', ') as genres,
                    COALESCE(AVG(ur.rating), m.rating) AS avg_rating,
                    (SELECT rating FROM user_ratings WHERE user_id = %s AND movie_id = m.movie_id) AS user_rating
                FROM movies m
                LEFT JOIN studios s ON m.studio_id = s.studio_id
                LEFT JOIN movie_genres mg ON m.movie_id = mg.movie_id
                LEFT JOIN genres g ON mg.genre_id = g.genre_id
                LEFT JOIN user_ratings ur ON m.movie_id = ur.movie_id
                WHERE m.movie_id = %s
                GROUP BY m.movie_id, s.studio_name, m.rating
            """
            cursor.execute(sql_movie, (user_id, movie_id))
            movie = cursor.fetchone()
            if not movie:
                return jsonify({"error": "Movie not found"}), 404
            
            # 2. Get Directors (Many-to-Many)
            sql_directors = "SELECT d.director_name FROM directors d JOIN movie_directors md ON d.director_id = md.director_id WHERE md.movie_id = %s"
            cursor.execute(sql_directors, (movie_id,))
            directors = cursor.fetchall()
            movie['directors'] = [d['director_name'] for d in directors]

            # 3. Get Cast (Many-to-Many with Role)
            sql_cast = "SELECT a.actor_name, mc.role FROM actors a JOIN movie_cast mc ON a.actor_id = mc.actor_id WHERE mc.movie_id = %s LIMIT 10"
            cursor.execute(sql_cast, (movie_id,))
            cast = cursor.fetchall()
            movie['cast'] = cast
        connection.close()
        return jsonify(movie)
    except Exception as e:
        print("MOVIE_DETAILS_ERROR:", str(e))
        return jsonify({"error": str(e)}), 500

# --- 14. API ROUTE: Rate a Movie (PROTECTED) ---
@app.route('/api/rate_movie/<int:movie_id>', methods=['POST'])
def rate_movie(movie_id):
    if 'user_id' not in session:
        return jsonify({"error": "You must be logged in to rate a movie."}), 401
    data = request.json
    rating = data.get('rating')
    user_id = session['user_id']
    if not rating or not (1 <= int(rating) <= 10):
        return jsonify({"error": "Invalid rating. Must be between 1 and 10."}), 400
    try:
        connection = pymysql.connect(host=DB_HOST, user=DB_USER, password=DB_PASSWORD, database=DB_DATABASE, cursorclass=pymysql.cursors.DictCursor)
        with connection.cursor() as cursor:
            sql = "INSERT INTO user_ratings (user_id, movie_id, rating) VALUES (%s, %s, %s) ON DUPLICATE KEY UPDATE rating = %s"
            cursor.execute(sql, (user_id, movie_id, rating, rating))
        connection.commit()
    except Exception as e:
        print("RATE_MOVIE_ERROR:", str(e))
        return jsonify({"error": str(e)}), 500
    finally:
        connection.close()
    return jsonify({"message": "Rating saved successfully"}), 201
    
# --- 15. ADMIN ROUTE: Get All Users (PROTECTED) ---
@app.route('/api/admin/users', methods=['GET'])
def get_all_users():
    if 'role' not in session or session['role'] != 'admin':
        return jsonify({"error": "Admin access required"}), 403
    try:
        connection = pymysql.connect(host=DB_HOST, user=DB_USER, password=DB_PASSWORD, database=DB_DATABASE, cursorclass=pymysql.cursors.DictCursor)
        with connection.cursor() as cursor:
            cursor.execute("SELECT user_id, first_name, last_name, username, email, mobile_no, role FROM users")
            users = cursor.fetchall()
        connection.close()
        return jsonify(users)
    except Exception as e:
        print("GET_ALL_USERS_ERROR:", str(e))
        return jsonify({"error": str(e)}), 500

# --- 16. ADMIN ROUTE: Delete a User (PROTECTED) ---
@app.route('/api/admin/delete_user/<int:user_id>', methods=['DELETE'])
def delete_user(user_id):
    if 'role' not in session or session['role'] != 'admin':
        return jsonify({"error": "Admin access required"}), 403
    if 'user_id' in session and session['user_id'] == user_id:
        return jsonify({"error": "Admin cannot delete their own account."}), 400
    try:
        connection = pymysql.connect(host=DB_HOST, user=DB_USER, password=DB_PASSWORD, database=DB_DATABASE)
        with connection.cursor() as cursor:
            sql = "DELETE FROM users WHERE user_id = %s"
            cursor.execute(sql, (user_id,))
        connection.commit()
        if cursor.rowcount == 0:
            return jsonify({"error": "User not found."}), 404
    except Exception as e:
        print("DELETE_USER_ERROR:", str(e))
        return jsonify({"error": str(e)}), 500
    finally:
        connection.close()
    return jsonify({"message": "User deleted successfully"}), 200

# --- 17. API ROUTE: Search TMDB (PROTECTED) ---
@app.route('/api/tmdb/search', methods=['GET'])
def search_tmdb():
    if 'role' not in session or session['role'] != 'admin':
        return jsonify({"error": "Admin access required"}), 403
    query = request.args.get('query')
    if not query:
        return jsonify({"error": "A 'query' is required."}), 400
    if not TMDB_API_KEY or TMDB_API_KEY == 'YOUR_TMDB_API_KEY_GOES_HERE':
        return jsonify({"error": "TMDB API key is not configured on the server."}), 500
    try:
        url = f"{TMDB_BASE_URL}/search/movie"
        params = {'api_key': TMDB_API_KEY, 'query': query}
        response = requests.get(url, params=params)
        response.raise_for_status() 
        return jsonify(response.json().get('results', []))
    except requests.exceptions.RequestException as e:
        print("TMDB_SEARCH_ERROR:", str(e))
        return jsonify({"error": str(e)}), 500

# --- 18. API ROUTE: Add Movie from TMDB (PROTECTED) ---
@app.route('/api/admin/add_movie', methods=['POST'])
def add_movie_from_tmdb():
    if 'role' not in session or session['role'] != 'admin':
        return jsonify({"error": "Admin access required"}), 403
    
    data = request.json
    tmdb_id = data.get('tmdb_id')
    if not tmdb_id:
        return jsonify({"error": "tmdb_id is required"}), 400
    if not TMDB_API_KEY or TMDB_API_KEY == 'YOUR_TMDB_API_KEY_GOES_HERE':
        return jsonify({"error": "TMDB API key is not configured on the server."}), 500

    try:
        # --- 1. Get Full Movie Details from TMDB ---
        url = f"{TMDB_BASE_URL}/movie/{tmdb_id}"
        params = {'api_key': TMDB_API_KEY, 'append_to_response': 'credits'}
        response = requests.get(url, params=params)
        response.raise_for_status()
        movie_data = response.json()

        # --- 2. Connect to our *local* MySQL database ---
        connection = pymysql.connect(host=DB_HOST, user=DB_USER, password=DB_PASSWORD, database=DB_DATABASE, cursorclass=pymysql.cursors.DictCursor)
        
        with connection.cursor() as cursor:
            # --- 3. Find or Create Studio ---
            studio_name = movie_data.get('production_companies', [{}])[0].get('name', 'Unknown')
            cursor.execute("SELECT studio_id FROM studios WHERE studio_name = %s", (studio_name,))
            studio = cursor.fetchone()
            if studio:
                studio_id = studio['studio_id']
            else:
                cursor.execute("INSERT INTO studios (studio_name) VALUES (%s)", (studio_name,))
                studio_id = cursor.lastrowid

            # --- 4. Insert the Movie ---
            sql = """
                INSERT INTO movies (title, release_year, running_time, rating, box_office_revenue, studio_id, synopsis, image_url)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
            """
            image_url = f"https://image.tmdb.org/t/p/w500{movie_data.get('poster_path')}"
            release_year = int(movie_data.get('release_date', '0000').split('-')[0])
            
            cursor.execute(sql, (
                movie_data.get('title'),
                release_year,
                movie_data.get('runtime'),
                movie_data.get('vote_average'),
                movie_data.get('revenue'),
                studio_id,
                movie_data.get('overview'),
                image_url
            ))
            movie_id = cursor.lastrowid

            # --- 5. Find or Create Genres and Link them ---
            for genre in movie_data.get('genres', []):
                genre_name = genre.get('name')
                cursor.execute("SELECT genre_id FROM genres WHERE genre_name = %s", (genre_name,))
                g = cursor.fetchone()
                if g:
                    genre_id = g['genre_id']
                else:
                    cursor.execute("INSERT INTO genres (genre_name) VALUES (%s)", (genre_name,))
                    genre_id = cursor.lastrowid
                cursor.execute("INSERT INTO movie_genres (movie_id, genre_id) VALUES (%s, %s) ON DUPLICATE KEY UPDATE movie_id=movie_id", (movie_id, genre_id))

            # --- 6. Find or Create Directors and Link them ---
            for crew_member in movie_data.get('credits', {}).get('crew', []):
                if crew_member.get('job') == 'Director':
                    director_name = crew_member.get('name')
                    cursor.execute("SELECT director_id FROM directors WHERE director_name = %s", (director_name,))
                    d = cursor.fetchone()
                    if d:
                        director_id = d['director_id']
                    else:
                        cursor.execute("INSERT INTO directors (director_name) VALUES (%s)", (director_name,))
                        director_id = cursor.lastrowid
                    cursor.execute("INSERT INTO movie_directors (movie_id, director_id) VALUES (%s, %s) ON DUPLICATE KEY UPDATE movie_id=movie_id", (movie_id, director_id))

            # --- 7. Find or Create Actors and Link them ---
            for actor in movie_data.get('credits', {}).get('cast', [])[:10]: # Get top 10 actors
                actor_name = actor.get('name')
                role = actor.get('character')
                cursor.execute("SELECT actor_id FROM actors WHERE actor_name = %s", (actor_name,))
                a = cursor.fetchone()
                if a:
                    actor_id = a['actor_id']
                else:
                    cursor.execute("INSERT INTO actors (actor_name) VALUES (%s)", (actor_name,))
                    actor_id = cursor.lastrowid
                cursor.execute("INSERT INTO movie_cast (movie_id, actor_id, role) VALUES (%s, %s, %s) ON DUPLICATE KEY UPDATE movie_id=movie_id", (movie_id, actor_id, role))
        
        connection.commit()
        
    except requests.exceptions.RequestException as e:
        print("TMDB_ADD_ERROR:", str(e))
        return jsonify({"error": "Failed to fetch data from TMDB"}), 500
    except pymysql.Error as e:
        print("DB_ADD_MOVIE_ERROR:", str(e))
        connection.rollback()
        return jsonify({"error": f"Database error: {str(e)}"}), 500
    except Exception as e:
        print("ADD_MOVIE_ERROR:", str(e))
        return jsonify({"error": f"An unexpected error occurred: {str(e)}"}), 500
    finally:
        if 'connection' in locals() and connection.open:
            connection.close()

    return jsonify({"message": f"Movie '{movie_data.get('title')}' added successfully to your database."}), 201

# --- 19. *** NEW *** API ROUTE: Get Movies by Genre ---
@app.route('/api/genre/<string:genre_name>', methods=['GET'])
def get_movies_by_genre(genre_name):
    user_id = session.get('user_id')
    try:
        connection = pymysql.connect(host=DB_HOST, user=DB_USER, password=DB_PASSWORD, database=DB_DATABASE, cursorclass=pymysql.cursors.DictCursor)
        with connection.cursor() as cursor:
            # This is the advanced JOIN query
            sql = """
                SELECT 
                    m.movie_id, m.title, m.release_year, m.image_url,
                    COALESCE(AVG(ur.rating), m.rating) AS avg_rating,
                    (SELECT rating FROM user_ratings WHERE user_id = %s AND movie_id = m.movie_id) AS user_rating
                FROM movies m
                JOIN movie_genres mg ON m.movie_id = mg.movie_id
                JOIN genres g ON g.genre_id = mg.genre_id
                LEFT JOIN user_ratings ur ON m.movie_id = ur.movie_id
                WHERE g.genre_name = %s
                GROUP BY m.movie_id, m.title, m.release_year, m.image_url, m.rating
                ORDER BY avg_rating DESC; -- Sort by rating
            """
            cursor.execute(sql, (user_id, genre_name))
            movies = cursor.fetchall()
        connection.close()
        return jsonify(movies)
    except Exception as e:
        print(f"GET_GENRE_MOVIES_ERROR: {str(e)}")
        return jsonify({"error": str(e)}), 500

# --- 20. Run the Application ---
if __name__ == '__main__':
    app.run(debug=True)