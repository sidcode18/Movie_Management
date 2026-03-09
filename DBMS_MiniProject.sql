/* ================================================================
FINAL SCRIPT FOR 'cinematic_vault' DATABASE
This script creates all tables, triggers, and 30 seed movies.
================================================================
*/

-- SECTION 1: DATABASE SETUP
DROP DATABASE IF EXISTS cinematic_vault;
CREATE DATABASE cinematic_vault;
USE cinematic_vault;

-- SECTION 2: TABLE CREATION (CORE ENTITIES)

CREATE TABLE studios (
    studio_id INT PRIMARY KEY AUTO_INCREMENT,
    studio_name VARCHAR(255) NOT NULL,
    location VARCHAR(255)
);

CREATE TABLE actors (
    actor_id INT PRIMARY KEY AUTO_INCREMENT,
    actor_name VARCHAR(255) NOT NULL,
    birth_date DATE,
    nationality VARCHAR(100)
);

CREATE TABLE directors (
    director_id INT PRIMARY KEY AUTO_INCREMENT,
    director_name VARCHAR(255) NOT NULL,
    birth_date DATE
);

CREATE TABLE genres (
    genre_id INT PRIMARY KEY AUTO_INCREMENT,
    genre_name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT
);

CREATE TABLE awards (
    award_id INT PRIMARY KEY AUTO_INCREMENT,
    award_name VARCHAR(255) NOT NULL,
    category VARCHAR(255),
    year INT
);

-- SECTION 3: TABLE CREATION (MOVIES, USERS, RATINGS)

CREATE TABLE movies (
    movie_id INT PRIMARY KEY AUTO_INCREMENT,
    title VARCHAR(255) NOT NULL,
    release_year INT NOT NULL,
    running_time INT,
    rating DECIMAL(3, 1) DEFAULT 7.0, -- Original/fallback rating
    box_office_revenue BIGINT,
    studio_id INT,
    synopsis TEXT,
    image_url VARCHAR(500), -- For the poster
    CONSTRAINT CHK_Rating CHECK (rating >= 0 AND rating <= 10),
    FOREIGN KEY (studio_id) REFERENCES studios(studio_id) ON DELETE SET NULL ON UPDATE CASCADE
);

CREATE TABLE users (
    user_id INT PRIMARY KEY AUTO_INCREMENT,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    username VARCHAR(100) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    mobile_no VARCHAR(20),
    role ENUM('user', 'admin') NOT NULL DEFAULT 'user'
);

CREATE TABLE user_ratings (
    rating_id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT,
    movie_id INT,
    rating INT NOT NULL,
    CONSTRAINT uc_user_movie UNIQUE (user_id, movie_id), -- A user can only rate a movie once
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (movie_id) REFERENCES movies(movie_id) ON DELETE CASCADE
);

-- SECTION 4: TABLE CREATION (JUNCTION & LOGGING)

CREATE TABLE movie_cast (
    movie_id INT,
    actor_id INT,
    role VARCHAR(255),
    PRIMARY KEY (movie_id, actor_id),
    FOREIGN KEY (movie_id) REFERENCES movies(movie_id) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (actor_id) REFERENCES actors(actor_id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE movie_directors (
    movie_id INT,
    director_id INT,
    PRIMARY KEY (movie_id, director_id),
    FOREIGN KEY (movie_id) REFERENCES movies(movie_id) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (director_id) REFERENCES directors(director_id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE movie_genres (
    movie_id INT,
    genre_id INT,
    PRIMARY KEY (movie_id, genre_id),
    FOREIGN KEY (movie_id) REFERENCES movies(movie_id) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (genre_id) REFERENCES genres(genre_id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE movie_awards (
    movie_id INT,
    award_id INT,
    PRIMARY KEY (movie_id, award_id),
    FOREIGN KEY (movie_id) REFERENCES movies(movie_id) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (award_id) REFERENCES awards(award_id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE movie_audit_log (
    log_id INT PRIMARY KEY AUTO_INCREMENT,
    movie_id INT,
    old_rating DECIMAL(3, 1),
    new_rating DECIMAL(3, 1),
    change_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (movie_id) REFERENCES movies(movie_id) ON DELETE CASCADE
);

-- SECTION 5: CREATE ADVANCED TRIGGERS

DELIMITER //
CREATE TRIGGER trg_movie_rating_audit
AFTER UPDATE ON movies
FOR EACH ROW
BEGIN
    IF OLD.rating <> NEW.rating THEN
        INSERT INTO movie_audit_log(movie_id, old_rating, new_rating)
        VALUES (OLD.movie_id, OLD.rating, NEW.rating);
    END IF;
END;
//
CREATE TRIGGER trg_check_actor_age
BEFORE INSERT ON movie_cast
FOR EACH ROW
BEGIN
    DECLARE movie_release_year INT;
    DECLARE actor_birth_year INT;

    SELECT release_year INTO movie_release_year
    FROM movies
    WHERE movie_id = NEW.movie_id;

    SELECT YEAR(birth_date) INTO actor_birth_year
    FROM actors
    WHERE actor_id = NEW.actor_id;

    IF actor_birth_year IS NOT NULL AND movie_release_year IS NOT NULL AND actor_birth_year > movie_release_year THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: Actor cannot be cast in a movie released before they were born.';
    END IF;
END;
//
DELIMITER ;

-- SECTION 6: POPULATE DATABASE WITH SEED DATA

-- Insert Studios (12 total)
INSERT INTO studios (studio_id, studio_name, location) VALUES
(1, 'Warner Bros. Pictures', 'Burbank, USA'),
(2, 'Marvel Studios', 'Burbank, USA'),
(3, 'Barunson E&A', 'Seoul, South Korea'),
(4, 'Paramount Pictures', 'Hollywood, USA'),
(5, 'Legendary Pictures', 'Burbank, USA'),
(6, 'Universal Pictures', 'Universal City, USA'),
(7, 'The Steve Tisch Company', 'Los Angeles, USA'),
(8, 'Castle Rock Entertainment', 'Beverly Hills, USA'),
(9, '20th Century Fox', 'Century City, USA'),
(10, 'New Line Cinema', 'Burbank, USA'),
(11, 'Studio Ghibli', 'Koganei, Japan'),
(12, 'Orion Pictures', 'Beverly Hills, USA');

-- Insert Directors (16 total)
INSERT INTO directors (director_id, director_name, birth_date) VALUES
(1, 'Christopher Nolan', '1970-07-30'),
(2, 'Anthony Russo', '1970-02-03'),
(3, 'Joe Russo', '1971-07-18'),
(4, 'Bong Joon-ho', '1969-09-14'),
(5, 'Francis Ford Coppola', '1939-04-07'),
(6, 'Robert Zemeckis', '1952-05-14'),
(7, 'David Fincher', '1962-08-28'),
(8, 'Lana Wachowski', '1965-06-21'),
(9, 'Lilly Wachowski', '1967-12-29'),
(10, 'Frank Darabont', '1959-01-28'),
(11, 'Hayao Miyazaki', '1941-01-05'),
(12, 'Peter Jackson', '1961-10-31'),
(13, 'Denis Villeneuve', '1967-10-03'),
(14, 'Quentin Tarantino', '1963-03-27'),
(15, 'Ridley Scott', '1937-11-30'),
(16, 'Stanley Kubrick', '1928-07-26');

-- Insert Actors (40 total)
INSERT INTO actors (actor_id, actor_name, birth_date, nationality) VALUES
(1, 'Leonardo DiCaprio', '1974-11-11', 'American'),
(2, 'Joseph Gordon-Levitt', '1981-02-17', 'American'),
(3, 'Elliot Page', '1987-02-21', 'Canadian'),
(4, 'Robert Downey Jr.', '1965-04-04', 'American'),
(5, 'Chris Evans', '1981-06-13', 'American'),
(6, 'Mark Ruffalo', '1967-11-22', 'American'),
(7, 'Song Kang-ho', '1967-01-17', 'South Korean'),
(8, 'Lee Sun-kyun', '1975-03-02', 'South Korean'),
(9, 'Marlon Brando', '1924-04-03', 'American'),
(10, 'Al Pacino', '1940-04-25', 'American'),
(11, 'Christian Bale', '1974-01-30', 'British'),
(12, 'Heath Ledger', '1979-04-04', 'Australian'),
(13, 'Cillian Murphy', '1976-05-25', 'Irish'),
(14, 'Emily Blunt', '1983-02-23', 'British'),
(15, 'Matthew McConaughey', '1969-11-04', 'American'),
(16, 'Anne Hathaway', '1982-11-12', 'American'),
(17, 'Tom Hanks', '1956-07-09', 'American'),
(18, 'Robin Wright', '1966-04-08', 'American'),
(19, 'Brad Pitt', '1963-12-18', 'American'),
(20, 'Keanu Reeves', '1964-09-02', 'Canadian'),
(21, 'Edward Norton', '1969-08-18', 'American'),
(22, 'Laurence Fishburne', '1961-07-30', 'American'),
(23, 'Tim Robbins', '1958-10-16', 'American'),
(24, 'Morgan Freeman', '1937-06-01', 'American'),
(25, 'Dave Goelz', '1946-07-16', 'American'),
(26, 'Elijah Wood', '1981-01-28', 'American'),
(27, 'Ian McKellen', '1939-05-25', 'British'),
(28, 'Timothée Chalamet', '1995-12-27', 'American'),
(29, 'Zendaya', '1996-09-01', 'American'),
(30, 'Ryan Gosling', '1980-11-12', 'Canadian'),
(31, 'John Travolta', '1954-02-18', 'American'),
(32, 'Samuel L. Jackson', '1948-12-21', 'American'),
(33, 'Mélanie Laurent', '1983-02-21', 'French'),
(34, 'Sigourney Weaver', '1949-10-08', 'American'),
(35, 'Jack Nicholson', '1937-04-22', 'American'),
(36, 'Jodie Foster', '1962-11-19', 'American'),
(37, 'Anthony Hopkins', '1937-12-31', 'British'),
(38, 'Margot Robbie', '1990-07-02', 'Australian'),
(39, 'Emma Stone', '1988-11-06', 'American'),
(40, 'Russell Crowe', '1964-04-07', 'New Zealander');

-- Insert Genres (14 total)
INSERT INTO genres (genre_id, genre_name, description) VALUES
(1, 'Sci-Fi', 'Science fiction genre'),
(2, 'Action', 'High-energy action-packed films'),
(3, 'Thriller', 'Evokes excitement and suspense'),
(4, 'Drama', 'Serious, character-driven stories'),
(5, 'Adventure', 'Involves an exciting or unusual experience'),
(6, 'Comedy', 'Designed to amuse and provoke laughter'),
(7, 'Crime', 'Deals with crime, detection, and criminals'),
(8, 'Biography', 'Based on a true life story'),
(9, 'History', 'Based on historical events'),
(10, 'Romance', 'Focuses on romantic love'),
(11, 'Animation', 'Animated films'),
(12, 'Fantasy', 'Fantasy world, magic, mythical creatures'),
(13, 'War', 'Films centered on warfare'),
(14, 'Horror', 'Films designed to frighten');

-- Insert Sample Awards (3 total)
INSERT INTO awards (award_id, award_name, category, year) VALUES
(1, 'Academy Award', 'Best Picture', 2020),
(2, 'Academy Award', 'Best Actor', 2009),
(3, 'Golden Globe', 'Best Director', 2014);

-- Insert 30 Seed Movies (with working poster links)
INSERT INTO movies (movie_id, title, release_year, running_time, rating, box_office_revenue, studio_id, synopsis, image_url) VALUES
(1, 'Inception', 2010, 148, 8.8, 829900000, 1, 'A thief who steals corporate secrets through dream-sharing technology is given the inverse task of planting an idea into a target''s subconscious.', 'https://image.tmdb.org/t/p/original/ljsZTbVsrQSqZgWeep2B1QiDKuh.jpg'),
(2, 'Avengers: Endgame', 2019, 181, 8.4, 2798000000, 2, 'After the devastating events of Avengers: Infinity War, the universe is in ruins. With the help of remaining allies, the Avengers assemble once more to reverse Thanos'' actions.', 'https://image.tmdb.org/t/p/w500/or06FN3Dka5tukK1e9sl16pB3iy.jpg'),
(3, 'Parasite', 2019, 132, 8.6, 258400000, 3, 'Greed and class discrimination threaten the newly formed symbiotic relationship between the wealthy Park family and the destitute Kim clan.', 'https://image.tmdb.org/t/p/w500/7IiTTgloJzvGI1TAYymCfbfl3vT.jpg'),
(4, 'The Godfather', 1972, 175, 9.2, 246100000, 4, 'The aging patriarch of an organized crime dynasty transfers control of his clandestine empire to his reluctant son.', 'https://image.tmdb.org/t/p/w500/3bhkrj58Vtu7enYsRolD1fZdja1.jpg'),
(5, 'The Dark Knight', 2008, 152, 9.0, 1005000000, 1, 'When the menace known as the Joker emerges, Batman must accept one of the greatest psychological and physical tests of his ability to fight injustice.', 'https://image.tmdb.org/t/p/original/xQPgyZOBhaz1GdCQIPf5A5VeFzO.jpg'),
(6, 'Oppenheimer', 2023, 180, 8.6, 952000000, 6, 'The story of American scientist J. Robert Oppenheimer and his role in the development of the atomic bomb.', 'https://image.tmdb.org/t/p/w500/8Gxv8gSFCU0XGDykEGv7zR1n2ua.jpg'),
(7, 'Interstellar', 2014, 169, 8.6, 701000000, 4, 'A team of explorers travel through a wormhole in space in an attempt to ensure humanity''s survival.', 'https://image.tmdb.org/t/p/original/gEU2QniE6E77NI6lCU6MxlNBvIx.jpg'),
(8, 'Forrest Gump', 1994, 142, 8.8, 678200000, 7, 'The presidencies of Kennedy and Johnson, the Vietnam War, the Watergate scandal, and other historical events unfold from the perspective of an Alabama man with an IQ of 75.', 'https://image.tmdb.org/t/p/w500/saHP97rTPS5eLmrLQEcANmKrsFl.jpg'),
(9, 'The Matrix', 1999, 136, 8.7, 463500000, 1, 'A computer hacker learns from mysterious rebels about the true nature of his reality and his role in the war against its controllers.', 'https://image.tmdb.org/t/p/w500/f89U3ADr1oiB1s9GkdPOEpXUk5H.jpg'),
(10, 'Fight Club', 1999, 139, 8.8, 101200000, 9, 'An insomniac office worker and a devil-may-care soap maker form an underground fight club that evolves into something much, much more.', 'https://image.tmdb.org/t/p/w500/pB8BM7pdSp6B6Ih7QZ4DrQ3PmJK.jpg'),
(11, 'Dune: Part Two', 2024, 166, 8.4, 711800000, 5, 'Follow the mythic journey of Paul Atreides as he unites with Chani and the Fremen while on a warpath of revenge against the conspirators who destroyed his family.', 'https://image.tmdb.org/t/p/original/czembW0Rk1Ke7lCJGahbOhdCuhV.jpg'),
(12, 'Blade Runner 2049', 2017, 164, 8.0, 259200000, 1, 'Young Blade Runner K''s discovery of a long-buried secret leads him to track down former Blade Runner Rick Deckard, who''s been missing for 30 years.', 'https://image.tmdb.org/t/p/original/jLul37v1NcF8XpdSEh4RHsmGocA.jpg'),
(13, 'Pulp Fiction', 1994, 154, 8.9, 213900000, 4, 'The lives of two mob hitmen, a boxer, a gangster''s wife, and a pair of diner bandits intertwine in four tales of violence and redemption.', 'https://image.tmdb.org/t/p/w500/d5iIlFn5s0ImszYzBPb8JPIfbXD.jpg'),
(14, 'The Shawshank Redemption', 1994, 142, 9.3, 28340000, 8, 'Two imprisoned men bond over a number of years, finding solace and eventual redemption through acts of common decency.', 'https://image.tmdb.org/t/p/original/9cqNxx0GxF0bflZmeSMuL5tnGzr.jpg'),
(15, 'Spirited Away', 2001, 125, 8.6, 355700000, 11, 'During her family''s move to the suburbs, a sullen 10-year-old girl wanders into a world ruled by gods, witches, and spirits, and where humans are changed into beasts.', 'https://image.tmdb.org/t/p/original/39wmItIWsg5sZMyRUHLkWBcuVCM.jpg'),
(16, 'The Lord of the Rings: The Return of the King', 2003, 201, 9.0, 1146000000, 10, 'Gandalf and Aragorn lead the World of Men against Sauron''s army to draw his gaze from Frodo and Sam as they approach Mount Doom with the One Ring.', 'https://image.tmdb.org/t/p/w500/rCzpDGLbOoPwLjy3OAm5NUPOTrC.jpg'),
(17, 'Spider-Man: Across the Spider-Verse', 2023, 140, 8.7, 690500000, 2, 'Miles Morales catapults across the Multiverse, where he encounters a team of Spider-People charged with protecting its very existence.', 'https://image.tmdb.org/t/p/original/8Vt6mWEReuy4Of61Lnj5Xj704m8.jpg'),
(18, 'GoodFellas', 1990, 146, 8.7, 46800000, 1, 'The story of Henry Hill and his life in the mob, covering his relationship with his wife Karen Hill and his mob partners Jimmy Conway and Tommy DeVito.', 'https://image.tmdb.org/t/p/original/aKuFiU82s5ISJpGZp7YkIr3kCUd.jpg'),
(19, 'Se7en', 1995, 127, 8.6, 327300000, 10, 'Two detectives, a rookie and a veteran, hunt a serial killer who uses the seven deadly sins as his motives.', 'https://image.tmdb.org/t/p/original/191nKfP0ehp3uIvWqgPbFmI4lv9.jpg'),
(20, 'Inglourious Basterds', 2009, 153, 8.3, 321500000, 6, 'In Nazi-occupied France during World War II, a plan to assassinate Nazi leaders by a group of Jewish U.S. soldiers coincides with a theatre owner''s vengeful plans.', 'https://image.tmdb.org/t/p/original/7sfbEnaARXDDhKm0CZ7D7uc2sbo.jpg'),
(21, 'Barbie', 2023, 114, 7.0, 1446000000, 1, 'Barbie suffers a crisis that leads her to question her world and her existence.', 'https://image.tmdb.org/t/p/original/iuFNMS8U5cb6xfzi51Dbkovj7vM.jpg'),
(22, 'Poor Things', 2023, 141, 8.3, 117500000, 9, 'The incredible tale about the fantastical evolution of Bella Baxter, a young woman brought back to life by the brilliant and unorthodox scientist Dr. Godwin Baxter.', 'https://image.tmdb.org/t/p/original/kCGlIMHnOm8JPXq3rXM6c5wMxcT.jpg'),
(23, 'The Shining', 1980, 146, 8.4, 47300000, 1, 'A family heads to an isolated hotel for the winter where a sinister presence influences the father into violence, while his psychic son sees horrific forebodings.', 'https://image.tmdb.org/t/p/original/xazWoLealQwEgqZ89MLZklLZD3k.jpg'),
(24, 'Alien', 1979, 117, 8.5, 106300000, 9, 'After a space merchant vessel perceives an unknown transmission as a distress call, one of the crew is attacked by a mysterious life form.', 'https://image.tmdb.org/t/p/original/vfrQk5IPloGg1v9Rzbh2Eg3VGyM.jpg'),
(25, 'Gladiator', 2000, 155, 8.5, 460500000, 6, 'A former Roman General sets out to exact vengeance against the corrupt emperor who murdered his family and sent him into slavery.', 'https://image.tmdb.org/t/p/original/5ZA4TZGfcEOkfChI73lPihoKd7N.jpg'),
(26, 'Joker', 2019, 122, 8.4, 1074000000, 1, 'In Gotham City, mentally troubled comedian Arthur Fleck is disregarded and mistreated by society. He then embarks on a downward spiral of revolution and bloody crime.', 'https://image.tmdb.org/t/p/w500/udDclJoHjfjb8Ekgsd4FDteOkCU.jpg'),
(27, 'Whiplash', 2014, 106, 8.5, 48900000, 3, 'A promising young drummer enrolls at a cut-throat music conservatory where his dreams of greatness are mentored by an abusive instructor.', 'https://image.tmdb.org/t/p/original/7fn624j5lj3xTme2SgiLCeuedmO.jpg'),
(28, 'Saving Private Ryan', 1998, 169, 8.6, 481800000, 4, 'Following the Normandy Landings, a group of U.S. soldiers go behind enemy lines to retrieve a paratrooper whose brothers have been killed in action.', 'https://image.tmdb.org/t/p/original/wUyhdcvGN9YCQ8SzRn1R04MHE2H.jpg'),
(29, 'Back to the Future', 1985, 116, 8.5, 381100000, 6, 'Marty McFly, a 17-year-old high school student, is accidentally sent 30 years into the past in a time-traveling DeLorean invented by his close friend.', 'https://image.tmdb.org/t/p/original/fNOH9f1aA7XRTzl1sAOx9iF553Q.jpg'),
(30, 'The Silence of the Lambs', 1991, 118, 8.6, 272700000, 12, 'A young F.B.I. cadet must receive the help of an incarcerated and manipulative cannibal killer to help catch another serial killer, a madman who skins his victims.', 'https://image.tmdb.org/t/p/original/kdHWRQpShAHfE7Q1a7Pdavd2uTl.jpg');

-- SECTION 8: LINK JUNCTION TABLES (FOR 30 MOVIES)

INSERT INTO movie_directors (movie_id, director_id) VALUES
(1, 1), (2, 2), (2, 3), (3, 4), (4, 5), (5, 1), (6, 1), (7, 1), (8, 6), (9, 8), (9, 9), (10, 7),
(11, 13), (12, 13), (13, 14), (14, 10), (15, 11), (16, 12), (17, 3), (18, 5), (19, 7), (20, 14),
(21, 1), (22, 1), (23, 16), (24, 15), (25, 15), (26, 1), (27, 1), (28, 6), (29, 6), (30, 7);

INSERT INTO movie_cast (movie_id, actor_id, role) VALUES
(1, 1, 'Cobb'), (1, 2, 'Arthur'), (1, 3, 'Ariadne'),
(2, 4, 'Tony Stark / Iron Man'), (2, 5, 'Steve Rogers / Captain America'), (2, 6, 'Bruce Banner / Hulk'),
(3, 7, 'Kim Ki-taek'), (3, 8, 'Park Dong-ik'),
(4, 9, 'Vito Corleone'), (4, 10, 'Michael Corleone'),
(5, 11, 'Bruce Wayne / Batman'), (5, 12, 'Joker'),
(6, 13, 'J. Robert Oppenheimer'), (6, 14, 'Kitty Oppenheimer'),
(7, 15, 'Cooper'), (7, 16, 'Brand'),
(8, 17, 'Forrest Gump'), (8, 18, 'Jenny Curran'),
(9, 20, 'Neo'), (9, 22, 'Morpheus'),
(10, 19, 'Tyler Durden'), (10, 21, 'The Narrator'),
(11, 28, 'Paul Atreides'), (11, 29, 'Chani'),
(12, 30, 'K'), (12, 16, 'Joi'),
(13, 31, 'Vincent Vega'), (13, 32, 'Jules Winnfield'),
(14, 23, 'Andy Dufresne'), (14, 24, 'Ellis "Red" Redding'),
(15, 25, 'Chihiro (voice)'), (16, 26, 'Frodo Baggins'), (16, 27, 'Gandalf'),
(17, 5, 'Miles Morales (voice)'), (18, 4, 'Henry Hill'), (19, 19, 'David Mills'), (19, 24, 'William Somerset'),
(20, 19, 'Lt. Aldo Raine'), (20, 33, 'Shosanna Dreyfus'),
(21, 38, 'Barbie'), (21, 30, 'Ken'),
(22, 39, 'Bella Baxter'), (22, 6, 'Dr. Godwin Baxter'),
(23, 35, 'Jack Torrance'), (24, 34, 'Ellen Ripley'),
(25, 40, 'Maximus'), (26, 1, 'Arthur Fleck'), -- Corrected Joker actor
(27, 5, 'Andrew Neiman'), (28, 17, 'Captain Miller'),
(29, 20, 'Marty McFly'), (30, 36, 'Clarice Starling'), (30, 37, 'Dr. Hannibal Lecter');

INSERT INTO movie_genres (movie_id, genre_id) VALUES
(1, 1), (1, 2), (1, 3), (2, 1), (2, 2), (2, 5), (3, 3), (3, 4), (3, 6), (4, 7), (4, 4),
(5, 2), (5, 7), (5, 4), (6, 8), (6, 9), (6, 4), (7, 1), (7, 5), (7, 4), (8, 4), (8, 10),
(9, 1), (9, 2), (10, 4), (11, 1), (11, 5), (12, 1), (12, 4), (13, 7), (13, 4), (14, 4),
(15, 11), (15, 12), (16, 12), (16, 5), (16, 4), (17, 11), (17, 2), (17, 5), (18, 8), (18, 7), (18, 4),
(19, 7), (19, 3), (20, 13), (20, 5), (20, 4), (21, 6), (21, 12), (22, 4), (22, 10), (22, 6),
(23, 4), (23, 14), (24, 14), (24, 1), (25, 2), (25, 5), (25, 4), (26, 7), (26, 4), (26, 3),
(27, 4), (28, 13), (28, 4), (29, 6), (29, 1), (29, 5), (30, 3), (30, 7), (30, 4);

-- SECTION 9: LINK SAMPLE AWARDS
INSERT INTO movie_awards (movie_id, award_id) VALUES
(3, 1), (5, 2), (7, 3);