DROP DATABASE IF EXISTS myDatabase;
CREATE DATABASE myDatabase;
USE myDatabase;

CREATE TABLE user (
	id int primary key auto_increment,
    firstname varchar(25),
    lastname varchar(25),
    email varchar(50) not null,
    -- password char(64) not null, -- base64 encoded
	created_at timestamp default now(),
    updated_at timestamp default now()
);

CREATE TABLE article (
	id int primary key auto_increment,
    title varchar(180) not null,
    text text not null,
    user_id int not null,
    created_at timestamp default now(),
    updated_at timestamp default now(),
    
    FOREIGN KEY(user_id) REFERENCES user(id)
);

CREATE TABLE tag (
	id int primary key auto_increment,
    value varchar(25)
);

CREATE TABLE article_has_tag (
	article_id int,
    tag_id int,
    
    primary key(article_id, tag_id)
);

CREATE TABLE comment (
	id int primary key auto_increment,
    text tinytext not null,
    user_id int not null,
    -- parent_id int default null, 
    article_id int not null,
	created_at timestamp default now(),
    updated_at timestamp default now(),
    
    CONSTRAINT author FOREIGN KEY(user_id) REFERENCES user(id),
    -- FOREIGN KEY(parent_id) REFERENCES comment(id),
    CONSTRAINT article FOREIGN KEY(article_id) REFERENCES article(id)
);

CREATE TABLE comment_has_upvote (
	comment_id int,
    user_id int,
    
    primary key(comment_id, user_id)
    #fk
);

CREATE TABLE article_has_view (
	article_id int not null,
    -- session_id varchar(90) not null,
    user_id int, -- nullable, nu necesita autentificare
    ip varchar(20) not null,
    -- agent varchar(30) not null,
	created_at timestamp,
    
    primary key(article_id, ip) -- va fi considerat view doar daca vine de la un IP diferit
);

-- =============== crt 2.2 (minim 5 alter table) ============================================================ --
#1 ne-am amintit... comentariile pot avea si raspunsuri
ALTER TABLE comment
	ADD parent_id int default null AFTER user_id,
    ADD CONSTRAINT reply_to FOREIGN KEY(parent_id) REFERENCES comment(id)
    ON DELETE CASCADE;

#2 article_has_view.created_at trebuie sa fie ca default data si ora la care inregistrarea a fost facuta
ALTER TABLE article_has_view
	MODIFY COLUMN created_at timestamp default now();

#3 article_has_view.user_id trebuie sa fie nullable, default null
ALTER TABLE article_has_view
	MODIFY COLUMN user_id int default null;

#4 article_has_view.user_id trebuie sa indice un utilizator (atunci cand e posibil)
ALTER TABLE article_has_view
	ADD FOREIGN KEY(user_id) REFERENCES user(id);

#5 user.email trebuie sa fie unic, sa contina un '@' si ceva mai scurt
ALTER TABLE user MODIFY
	email varchar(40) unique not null CHECK(locate('@', email) > 1);

#6 cand user se sterge, articolele vor ramane anonim, insa comentariile se vor sterge, la fel si cand se sterge un articol
ALTER TABLE comment
	DROP FOREIGN KEY author,
    DROP FOREIGN KEY article,
    ADD CONSTRAINT author1 FOREIGN KEY(user_id) REFERENCES user(id) ON DELETE CASCADE,
    ADD CONSTRAINT article1 FOREIGN KEY(article_id) REFERENCES article(id) ON DELETE CASCADE;

-- =============== crt 3.1 (minim 10 inserts) ============================================================ --
# minim 10 inserari de utilizatori
INSERT INTO user (firstname, lastname, email) VALUES
	("Florin", "Botea", "florinbotea1693@gmail.com"),
	("Nealson", "Orrin", "norrin1@soup.io"),
	("Beret", "Longmate", "blongmate0@imdb.com"),
	("Hunt", "Snel", "hsnel2@blogger.com"),
	("Arliene", "Bende", "abende3@ftc.gov"),
	("Arliene", "d' Elboux", "tdelboux4@apple.com"),
	("Giff", "Tackle", "gtackle5@squidoo.com"),
	("Wallache", "Aronstam", "waronstam6@amazonaws.com"),
	("Mildred", "McGahern", "mmcgahern7@zdnet.com"),
	("Stevie", "Abbatt", "sabbatt8@amazon.co.uk"),
	("Kiel", "Elden", "kelden9@abc.net.au");
		
# minim 10 inserari de articole .... scuze... am incercat sa trunchez lungimea unui articol
# de asemenea, indent-ul facut aici va insera in baza de date randurile unite cu lungimi de tab-uri intre ele
# poate voi corecta asta cu un viitor update
INSERT INTO article (title, text, user_id) VALUES
	("Nullam tristique, quam a maximus placerat, nulla massa interdum magna",
    "Nullam tristique, quam a maximus placerat, nulla massa interdum magna, eget gravida turpis mauris 
    et erat. Proin a diam vitae libero egestas varius non non sapien. Maecenas eleifend orci quis tellus 
    egestas, ut egestas diam maximus. Maecenas porttitor finibus metus in convallis. Donec sodales posuere 
    urna, non sollicitudin odio ultrices eu. Aliquam convallis consequat velit, et pretium nulla rutrum eget. 
    Praesent at quam turpis. Duis lacinia massa eu lectus pharetra, et euismod elit cursus. In metus elit, 
    mattis at commodo at, cursus id est. Morbi rutrum quam nunc, eu sagittis tortor venenatis eu.", 1),
    ("Nam eget tincidunt ipsum, eu lacinia nibh",
    "Pellentesque non augue sit amet lorem maximus iaculis. Nam eget tincidunt ipsum, eu lacinia nibh. Vestibulum 
    dictum pharetra erat mattis scelerisque. Donec facilisis libero eget velit dictum, sit amet laoreet mauris 
    mattis. Suspendisse imperdiet dapibus quam. Proin condimentum elit tincidunt, aliquet tortor sit amet, 
    efficitur lacus. Integer ornare felis vitae enim tincidunt, quis feugiat dolor vehicula. Maecenas nulla quam, 
    accumsan sed vestibulum id, fringilla ac nisl. Curabitur blandit magna eu erat sollicitudin, at dapibus ante 
    tincidunt. Morbi a libero non nibh euismod condimentum. Duis ultrices dui ante, sed porttitor orci facilisis a. 
    Nullam mi leo, auctor vel sodales eu, rutrum at turpis.", 1),
    ("Nunc eget massa varius, congue ligula at, tincidunt sem",
    "Nunc eget massa varius, congue ligula at, tincidunt sem. Vivamus lectus nisi, rhoncus eget elit ut, 
    rhoncus lacinia nisl. Praesent scelerisque odio nec dui imperdiet semper. Aenean euismod, sapien 
    id convallis lacinia, risus lacus elementum leo, id fringilla nunc orci vel turpis. Nulla nunc nulla, 
    vulputate eu volutpat eget, elementum vel nunc. Phasellus convallis urna consequat bibendum condimentum. 
    Morbi pulvinar fringilla massa, ut maximus neque posuere finibus. Etiam ullamcorper fermentum metus, 
    non venenatis tellus volutpat nec. Nulla accumsan sit amet nisl quis feugiat. Fusce volutpat efficitur 
    risus sit amet congue. Nunc sit amet metus felis. Donec rhoncus, tellus a tincidunt varius, dolor 
    felis sollicitudin lorem, eu mattis tortor tortor vitae lorem. Cras vehicula tellus id elit elementum 
    faucibus. Cras ac tincidunt ante, ut tincidunt risus. Morbi at posuere lectus, quis commodo libero.", 2),
    ("Duis pharetra sem ac malesuada posuere",
    "Duis pharetra sem ac malesuada posuere. Cras consequat lorem eu est molestie faucibus. Nunc ut convallis 
    metus. In eget sagittis orci. Duis vel lacus pulvinar, vehicula odio vel, dapibus libero. Phasellus et 
    dapibus justo. Aliquam tristique a sapien quis dignissim. Morbi dictum ornare consequat. Curabitur sed 
    odio accumsan, lobortis libero eget, tincidunt ante. Mauris lacinia metus justo, id venenatis nulla dictum 
    sollicitudin. Maecenas lobortis nec velit sed vestibulum. In condimentum, elit fringilla semper cursus, ex 
    justo blandit justo, ac ultricies massa massa nec arcu. Praesent viverra tortor tincidunt turpis tincidunt, 
    eu aliquet nisl dictum. Vivamus hendrerit condimentum neque, eget interdum purus facilisis sit amet.", 3),
    ("Nulla vel dui bibendum, semper risus eget",
    "Nulla vel dui bibendum, semper risus eget, condimentum augue. Morbi luctus laoreet porta. Vestibulum 
    tincidunt, augue at laoreet scelerisque, leo urna sodales arcu, eu convallis augue nibh vitae velit. 
    Sed sed dapibus quam. Pellentesque sit amet augue ante. Morbi vel mi quam. Duis sit amet feugiat elit. 
    Cras euismod leo vitae imperdiet suscipit.", 4),
    ("Sed sollicitudin imperdiet diam, eget viverra quam tincidunt ac",
    "Sed sollicitudin imperdiet diam, eget viverra quam tincidunt ac. Curabitur bibendum arcu ipsum, quis 
    suscipit nisl bibendum a. Nunc turpis nunc, ornare aliquam ligula nec, iaculis semper velit. Duis id 
    tellus diam. Phasellus sagittis magna sapien, vel auctor erat dapibus vitae. Mauris a ligula quis dui ornare 
    dapibus. Pellentesque at malesuada nisi. Aenean egestas enim et purus rhoncus, vitae lacinia massa iaculis. 
    Duis iaculis nulla sed mauris tincidunt, id blandit mi facilisis. Pellentesque dapibus lacus eros, ut volutpat 
    massa lacinia quis. Morbi tincidunt, felis et ornare viverra, mi dui viverra elit, sed rutrum ante urna a 
    ipsum. Phasellus vehicula ex at elit mattis pretium.", 5),
    ("Quisque ac ex eleifend, gravida lorem luctus, posuere felis",
    "Quisque ac ex eleifend, gravida lorem luctus, posuere felis. Duis ut quam quis justo viverra aliquam vel 
    at dui. Phasellus vestibulum lacus sed tincidunt mattis. Orci varius natoque penatibus et magnis dis 
    parturient montes, nascetur ridiculus mus. Donec condimentum turpis felis. Praesent tincidunt enim ipsum, 
    non condimentum risus vulputate at. Duis pulvinar varius turpis eu vehicula.", 6),
    ("Donec ullamcorper mollis neque, non malesuada",
    "Donec ullamcorper mollis neque, non malesuada quam mollis a. Duis eleifend semper metus, vel viverra ipsum 
    tempor vitae. Cras dolor enim, consectetur non rhoncus vel, blandit ac felis. Curabitur nibh sapien, 
    hendrerit vitae sagittis a, venenatis sit amet erat. Curabitur tincidunt vitae nibh sed pharetra. Ut tempus 
    libero eget scelerisque tincidunt. Nullam ut nisi id massa finibus pretium. Pellentesque tempor lorem eget 
    libero cursus posuere. Maecenas sit amet tellus ac ex condimentum euismod ut at ante. Sed sollicitudin ipsum 
    eget ex varius tincidunt. Phasellus eu ligula est. Pellentesque elementum rhoncus leo, eu vulputate odio 
    varius at. Nam elit leo, porttitor sed mollis ac, suscipit eget diam. Nulla elementum ullamcorper ex pharetra 
    dignissim. In aliquet maximus tempus.", 7),
    ("Phasellus a sem fermentum, eleifend erat quis",
    "Phasellus a sem fermentum, eleifend erat quis, dignissim sapien. Integer vitae metus eget metus consequat 
    lobortis. Vestibulum tempor mattis feugiat. Phasellus nec egestas leo. Sed nec sem vitae elit consectetur 
    molestie a at ipsum. Nunc auctor enim id elit dictum, vel sagittis tellus tempus. Donec non placerat orci. 
    Aliquam mi mauris, auctor vel lacinia non, luctus id leo. Sed ac quam nulla. Nunc aliquam rhoncus ligula, 
    at commodo massa rutrum eu. Integer accumsan posuere dictum.", 7),
    ("Pellentesque porttitor tellus non arcu finibus",
    "Pellentesque porttitor tellus non arcu finibus, ac tempus eros elementum. Phasellus at ligula non felis 
    consectetur tempus quis id velit. Nullam non facilisis elit. Curabitur ultricies euismod sapien, sit amet 
    efficitur est placerat at. In sem risus, laoreet at ullamcorper nec, aliquet non felis. Quisque viverra 
    pellentesque sem non dapibus. Praesent non vehicula quam. Pellentesque vestibulum turpis mi, vitae lacinia 
    mi efficitur lobortis. Cras ante diam, feugiat ac eleifend quis, fermentum maximus sem. Sed iaculis vehicula 
    mi. Proin vestibulum imperdiet ipsum sed euismod. Integer posuere accumsan ipsum a varius.", 8);
    
# minim 10 inserari de tags
INSERT INTO tag(value) VALUES
	("sport"), -- 1
    ("health"), -- 2
    ("politic"), -- 3
    ("movies"), -- 4
    ("news"), -- 5
    ("technology"), -- 6
    ("psychology"), -- 7
    ("culture"), -- 8
    ("travel"), -- 9
    ("conspiracy"); -- 10

# minim 10 inserari de article_has_tag
# inserez la fiecare articol in parte cateva tag-uri, le grupez pe coloane sa fie mai logic
INSERT INTO article_has_tag(article_id, tag_id) VALUES
	(1, 1), 
    (1, 2),
    (2, 2),
    (3, 3), 
    (3, 5),
    (4, 4), 
    (4, 8),
    (5, 7), 
    (5, 2),
    (6, 10), 
    (6, 6), 
    (6, 5),
    (7, 9), 
    (7, 8),
    (8, 10), 
    (8, 3),
    (9, 8), 
    (9, 4), 
    (9, 3), 
    (10, 1), 
    (10, 5);
    
# minim 10 inserari de comment
INSERT INTO comment(text, user_id, parent_id, article_id) VALUES
	("Mauris eu sem dignissim, luctus nisi et, gravida arcu. Fusce vitae augue semper, ullamcorper elit.", 1, null, 1), -- 1
    ("Nunc neque massa, blandit vel lorem sit amet, tempor viverra velit. Ut egestas eros vitae.", 2, 1, 1), -- 2
    ("Suspendisse eu efficitur orci, vel commodo lacus. Etiam efficitur nisl nec interdum imperdiet.", 1, 2, 1), -- 3
    ("Maecenas convallis, magna in dignissim placerat, ex urna molestie libero, quis pharetra risus turpis eget.", 3, 2, 1), -- 4
    ("Donec egestas tempor ligula, ut varius lacus vehicula non. Pellentesque scelerisque, erat in aliquam lacinia.", 4, null, 1), -- 5
    ("Fusce posuere vel velit sit amet fermentum. Praesent mattis, erat a gravida ullamcorper, elit libero.", 5, null, 2), -- 6
    ("Curabitur sed pulvinar ante. Curabitur viverra vulputate lobortis. Fusce dictum luctus ipsum eu venenatis. Duis.", 6, 6, 2), -- 7
    ("Suspendisse vestibulum quam ut ipsum pulvinar interdum. Aliquam id urna eget tellus cursus convallis et.", 6, null, 3), -- 8
    ("Vestibulum suscipit, mi et sagittis aliquet, sapien magna vehicula dui, ut placerat quam ex nec.", 9, null, 5), -- 9
    ("Mauris facilisis consequat mauris id vehicula. Vestibulum ante ipsum primis in faucibus orci luctus et.", 8, 7, 2); -- 10
    
# minim 10 inserari de comment_has_upvote
INSERT INTO comment_has_upvote(comment_id, user_id) VALUES
	(1, 2), 
    (1, 3), 
    (1, 4),
    (2, 1), 
    (2, 3),
    (3, 5), 
    (3, 4),
    (4, 2), 
    (4, 7),
    (5, 1), 
    (5, 3), 
    (5, 2), 
    (5, 8),
    (6, 1),
    (7, 2), 
    (7, 9);
    
# minim 10 inserari de article_has_view
INSERT INTO article_has_view(article_id, user_id, ip) VALUES
	(1, 1, "192.168.1.1"),
    (3, 1, "192.168.1.2"),
    (3, 1, "192.168.1.1"),
    (4, 1, "192.168.1.1"),
    (5, 1, "192.168.1.1"),
    (3, 2, "193.162.1.1"),
    (4, 2, "193.162.1.1"),
    (5, 2, "193.162.1.1"),
    (6, 2, "193.162.1.1"),
    (8, 2, "193.162.1.1"),
    (4, 3, "194.162.1.1"),
    (1, 4, "194.162.1.1"),
    (7, 5, "194.162.1.1"),
    (7, null, "191.162.1.1"),
    (8, null, "191.162.1.1"),
    (9, null, "191.162.1.1"),
    (1, null, "191.162.1.1");
    
-- =============== crt 3.2 (minim 3 updates) ============================================================ --
# din cauza faptului ca am rupt textul articolelor pe mai multe randuri (pentru lizibilitate), 
# dar am si dorit sa pastrez indent-ul, indent-ul de la fiecare rand s-a inserat in db ca x4 spatii (cred)
# trebuie sa corectam asta - 
-- before: select text from article;
# select REGEXP_REPLACE("foo     bar baz", "\\s{2,}", "-"); -- regexp '[ ]+' da match pentru fiecare minim 2 spatii dintr-un string
SET SQL_SAFE_UPDATES = 0;
UPDATE article SET
	text = REGEXP_REPLACE(text, "\\s{2,}", " ");
-- after: select text from article;
# swap intre nume si prenume autorului articolului cu id = 1
UPDATE user SET firstname=(@temp:=firstname), firstname = lastname, lastname = @temp
	WHERE id = (SELECT user_id FROM article WHERE id = 1);
    
# update comment
UPDATE comment SET text = "Acest comentariu a fost editat", updated_at = now()
	WHERE id = 6;
    
-- =============== crt 3.3 (minim 3 delete) ============================================================ --
# sterg comentariul cu cele mai putine upvote-uri, dar nu mai vechi de 2 zile
INSERT INTO comment (text, user_id, parent_id, article_id, created_at, updated_at) VALUES
	("Acest comentariu va fi sters", 1, null, 1, date_sub(now(), interval 3 day), date_sub(now(), interval 3 day));

DELETE FROM comment WHERE id = (
	SELECT id FROM comment
		LEFT JOIN comment_has_upvote ON comment.id = comment_has_upvote.comment_id
        WHERE comment.created_at < date_sub(now(), interval 2 day)
		GROUP BY comment_has_upvote.comment_id
		ORDER BY count(comment_has_upvote.comment_id), comment.created_at
		LIMIT 1
);

# sterg cel mai vechi articol slab
DELETE FROM article WHERE id = (
	SELECT id FROM article
		LEFT JOIN article_has_view ON article.id = article_has_view.article_id
		GROUP BY article_has_view.article_id
		ORDER BY count(article_has_view.article_id), article.created_at
		LIMIT 1
);

# sterg toate upvote-urile date de autorul comentariului (e incorect sa ne votam singuri, desi e democratie)
INSERT INTO comment_has_upvote(comment_id, user_id) VALUES(1, 1); -- auto upvote
DELETE comment_has_upvote FROM comment_has_upvote
	INNER JOIN comment ON comment_has_upvote.comment_id = comment.id
    WHERE comment_has_upvote.user_id = comment.user_id;

-- =============== crt 4.1 (minim 3 subinterogari) ============================================================ --
# selectam toate comentariile utilizatorului cu numele Nealson Orrin
SELECT * FROM comment WHERE user_id = (
	SELECT id FROM user WHERE firstname = "Nealson" AND lastname = "Orrin"
);

# selectam toate comentariile utilizatorului care are cele mai votate comentarii
SELECT * FROM comment WHERE user_id = (
	SELECT comment.user_id FROM comment 
		LEFT JOIN comment_has_upvote ON comment.id = comment_has_upvote.comment_id
		GROUP BY comment_has_upvote.comment_id 
        ORDER BY count(comment_has_upvote.comment_id) DESC LIMIT 1
);

# selectam un preview la articolele avand comentarii
SELECT substring(text, 1, 30) FROM article WHERE id IN (
	SELECT article_id FROM comment
		GROUP BY article_id
);
        
-- =============== crt 4.2 (minim 3 join-uri) facute mai sus ============================================================ --
# selectam comentarii la articol 1 alaturi de utilizatori
SELECT comment.text, concat_ws(" ", user.firstname, user.lastname) as user_name FROM comment
	INNER JOIN user ON comment.id = user.id
    WHERE comment.article_id = 1;

# selectam clasamentul userilor ce au dat cele mai multe voturi
SELECT concat_ws(" ", user.firstname, user.lastname) FROM user
	INNER JOIN comment_has_upvote ON user.id = comment_has_upvote.user_id
    GROUP BY comment_has_upvote.user_id
    ORDER BY count(comment_has_upvote.user_id) DESC;

# selectam clasamentul userilor care au vazut cele mai multe articole, minim 2 vazute
SELECT concat_ws(" ", user.firstname, user.lastname) as user_name FROM user
	INNER JOIN article_has_view ON user.id = article_has_view.user_id
    GROUP BY article_has_view.user_id
	HAVING count(article_has_view.user_id) > 1
    ORDER BY count(article_has_view.user_id) DESC;

-- =============== crt 4.3 (minim 3 functii de grup/having) folosite mai sus ============================================================ --

-- =============== crt 4.4 (minim 3 funcţii predefinite MySQL: matematice, de comparare, condiţionale, pentru şiruri de 
-- caractere, pentru date calendaristice) folosite ============================================================ --

-- =============== crt 5 (minim 2 view) ============================================================ --

CREATE VIEW comment_with_author AS
	SELECT comment.text, concat(substr(user.firstname, 1, 1), ". ", user.lastname) as name FROM COMMENT
		INNER JOIN user ON comment.user_id = user.id;
        
CREATE VIEW article_preview_with_count_views AS
	SELECT article.text, user.firstname, user.lastname, count(article_has_view.article_id) as views FROM article
		INNER JOIN user ON article.user_id = user.id
        LEFT JOIN article_has_view ON article.id = article_has_view.article_id
        GROUP BY article_has_view.article_id;

select * FROM comment_with_author;
select * FROM article_preview_with_count_views;

-- =============== crt 6 (minim 3 functii) ============================================================ --

DELIMITER //
CREATE FUNCTION get_article_comments_count(article_id int) returns int
begin
	declare comments_count int;
	SELECT count(article_id) into comments_count FROM comment
		WHERE comment.article_id = article_id;
	return comments_count;
end;
//
delimiter ;

delimiter //
CREATE FUNCTION get_article_views_count(article_id int) returns int
begin
	declare views_count int;
	SELECT count(article_id) into views_count FROM article_has_view
		WHERE article_has_view.article_id = article_id;
	return views_count;
end;
//
delimiter ;

delimiter //
CREATE FUNCTION user_has_voted_comment(user_id int, comment_id int) returns enum("true", "false")
begin
	declare has_upvoted varchar(5);
    declare count_records int;
	SELECT count(comment_has_upvote.user_id) into count_records FROM comment_has_upvote
		WHERE comment_has_upvote.user_id = user_id AND comment_has_upvote.comment_id = comment_id;
	if (count_records > 0) then set has_upvoted = "true";
		else set has_upvoted = "false";
	end if;
    return has_upvoted;
end;
//
DELIMITER ;

select get_article_comments_count(1);
select get_article_views_count(1);
select user_has_voted_comment(1, 1);

-- =============== crt 6 (minim 3 proceduri) ============================================================ --

-- =============== crt 6 (minim 3 cursori) ============================================================ --

-- =============== crt 6 (minim 3 triggeri) ============================================================ --