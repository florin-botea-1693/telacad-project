/*
	baza de date a unui blog care va avea urmatoarele functii (in mare):
    - adaugare articol de catre utilizator
    - un articol poate avea vizualizari de la un user inregistrat, sau de la un anonim
    - valorile inregistrate in tabela article_has_view in dreptul unui user ii pot genera un profil de interese
    - articolul va avea tag-uri ce pot fi folosite pentru a face o legatura semantica spre alte articole - similare
    - articolele vor avea comentarii postate de alti utilizatori
    - comentariile pot avea upvote-uri de la alti utilizatori
    - comentariile se propun a fi structurate ierarhic - ma voi ocupa de aspectul asta in ultima parte a proiectului.
    Am gasit ca solutie folosirea de triggeri pentru a da o structura thread-urilor de comentarii,
    deoarece (desi am cautat) recursivitatea e cam dificila. comment.comment_path va fi de genul 1/2/3 => comentariul curent e 
    raspuns la comentariul 3, care e raspuns la comentariul 2, care e raspuns la comentariul 1, care e comentariu root
    - cateva operatiuni complicate vor fi computate periodic in anumite coloane (ex: computed_tags, count_votes), 
    astfel incat baza de date sa aiba un boost pe operatiuni de read
    
    Comentarii:
    -- ============================= pentru a separa vizual cerintele de capitol
    -- ----------------------------- pentru a separa vizual subcerintele de capitol
    # comentarii local scope
*/

DROP DATABASE IF EXISTS myDatabase;
CREATE DATABASE myDatabase;
USE myDatabase;

SET SQL_SAFE_UPDATES = 0;

/*
	User este actorul principal in baza de date. Lui ii revin operatiuni de create, read, update, delete
    asupra tututor coloanelor (aproape), inclusiv catre coloana user (un user se poate sterge)
*/
CREATE TABLE user (
	id int primary key auto_increment,
    firstname varchar(25),
    lastname varchar(25),
    email varchar(50) not null,
    -- count_votes int default 0, -- adaugat la randul 559
	created_at timestamp default now(),
    updated_at timestamp default now()
);

/*
	Articolul este obiectul de interes al bazei de date. Este creat, vizualizat, comentat de user.
    Atunci cand un user se sterge, articolul lui va ramane sub anonimat -- vezi triggers
*/
CREATE TABLE article (
	id int primary key auto_increment,
    title varchar(180) not null,
    text text not null,
    user_id int not null,
    -- computed_tags varchar(70) default null, -- aceasta coloana a fost adaugata ulterior pentru cursori si triggeri
    created_at timestamp default now(),
    updated_at timestamp default now(),
    
    FOREIGN KEY(user_id) REFERENCES user(id)
);

/*
	Articolele sunt legate intre ele prin tag-uri. Atunci cand accesam un articol, pot aparea in josul paginii
    articole similare cu cel citit. Tag-urile dau identitate unui articol, dar si similitudini cu alte articole
*/
CREATE TABLE tag (
	id int primary key auto_increment,
    value varchar(25)
);

/*
	many to many (articol are tag-uri, tag apartine articole)
*/
CREATE TABLE article_has_tag (
	article_id int,
    tag_id int,
    
    primary key(article_id, tag_id)
);

/*
	Comentariiel sunt reactia user-ului la un anumit articol. Un articol comentat, e un articol popular, cu impact.
    Atunci cand un user se sterge, comentariile lui se sterg... 
*/
CREATE TABLE comment (
	id int primary key auto_increment,
    text tinytext not null,
    user_id int not null,
    -- parent_id int default null, -- adaugat prin alter table la randul 123
    article_id int not null,
    -- count_votes int default 0, -- adaugat in randul 557
	created_at timestamp default now(),
    updated_at timestamp default now(),
    
    CONSTRAINT author FOREIGN KEY(user_id) REFERENCES user(id),
	-- FOREIGN KEY(parent_id) REFERENCES comment(id) ON DELETE CASCADE, -- adaugat prin alter table la randul 124
    CONSTRAINT article FOREIGN KEY(article_id) REFERENCES article(id)
);

CREATE TABLE comment_has_upvote (
	comment_id int,
    user_id int,
    
    primary key(comment_id, user_id),
    foreign key(comment_id) references comment(id) on delete cascade
);

/*
	Esential. In baza view-urilor si a tag-urilor de articole,
    pot oferi utilizatorului sugestii de articole care sa fie in sfera lui de interes.
*/
CREATE TABLE article_has_view (
	article_id int not null,
    -- session_id varchar(90) not null,
    user_id int, -- nullable, nu necesita autentificare
    ip varchar(20) not null,
    -- agent varchar(30) not null,
	created_at timestamp,
    
    primary key(article_id, ip),
    foreign key(article_id) references article(id) on delete cascade-- va fi considerat view doar daca vine de la un IP diferit
);

-- =============== crt 2.2 (minim 5 alter table) ============================================================ --
#1 ne-am amintit... comentariile pot avea si raspunsuri
ALTER TABLE comment
	ADD parent_id int default null AFTER user_id,
    ADD CONSTRAINT reply_to FOREIGN KEY(parent_id) REFERENCES comment(id) ON DELETE CASCADE;

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
	email varchar(40) unique not null CHECK(locate('@', email) > 1); -- <-- nu stiu de ce apare o eroare, dar merge...
# INSERT INTO user (firstname, lastname, email) VALUES("Florin", "Botea", "foo.bar.com") va esua

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
	("Beret", "Longmate", "blongmate0@gmail.com"),
	("Hunt", "Snel", "hsnel2@gmail.com"),
	("Arliene", "Bende", "abende3@ftc.gov"),
	("Arliene", "d' Elboux", "tdelboux4@apple.com"),
	("Giff", "Tackle", "gtackle5@gmail.com"),
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
# inserez intai un comentariu mai vechi de 3 zile
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

# sterg cel mai vechi articol care are cele mai putine vizualizari
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
SELECT substring(text, 1, 30) as article_preview FROM article WHERE id IN (
	SELECT article_id FROM comment
		GROUP BY article_id
);
        
-- =============== crt 4.2 (minim 3 join-uri) ============================================================ --
# selectam comentarii la articol 1 alaturi de utilizatori
SELECT comment.text, concat_ws(" ", user.firstname, user.lastname) as user_name FROM comment
	INNER JOIN user ON comment.id = user.id
    WHERE comment.article_id = 1;

# selectam clasamentul userilor ce au dat cele mai multe voturi
SELECT concat_ws(" ", user.firstname, user.lastname) as user_name FROM user
	INNER JOIN comment_has_upvote ON user.id = comment_has_upvote.user_id
    GROUP BY comment_has_upvote.user_id
    ORDER BY count(comment_has_upvote.user_id) DESC;

# selectam clasamentul userilor care au vazut cele mai multe articole, minim 2 vazute
SELECT concat_ws(" ", user.firstname, user.lastname) as user_name FROM user
	INNER JOIN article_has_view ON user.id = article_has_view.user_id
    GROUP BY article_has_view.user_id
	HAVING count(article_has_view.user_id) > 1
    ORDER BY count(article_has_view.user_id) DESC;

-- =============== crt 4.3 (minim 3 functii de grup/having) ============================================================ --
# selectam numarul total de voturi obtinute de utilizatorul cu id 1
SELECT count(comment_has_upvote.comment_id) as count_total_upvotes FROM user
	LEFT JOIN comment on user.id = comment.user_id
    LEFT JOIN comment_has_upvote on comment.id = comment_has_upvote.comment_id
    WHERE user.id = 1
    GROUP BY user.id;
    
# selectam numarul de voturi obtinute in medie de utilizator 1 per comentariu
SELECT avg(r.count_upvotes) as count_upvotes FROM (
	SELECT count(comment_has_upvote.comment_id) as count_upvotes FROM user
		LEFT JOIN comment on user.id = comment.user_id
		LEFT JOIN comment_has_upvote on comment.id = comment_has_upvote.comment_id
		WHERE user.id = 1
		GROUP BY comment.id
) r;

# selectam numarul total de voturi obtinute de un user
SELECT count(comment_has_upvote.comment_id) as count_upvotes FROM user
	LEFT JOIN comment on user.id = comment.user_id
	LEFT JOIN comment_has_upvote on comment.id = comment_has_upvote.comment_id
	WHERE user.id = 1
	GROUP BY user.id;
    
# selectam tag-urile unui articol
SELECT group_concat(tag.value separator ", ") as tags FROM article
	LEFT JOIN article_has_tag ON article.id = article_has_tag.article_id
    INNER JOIN tag ON article_has_tag.tag_id = tag.id
	WHERE article.id = 1;
  
-- =============== crt 4.4 (minim 3 funcţii predefinite MySQL: matematice, de comparare, condiţionale, pentru şiruri de 
-- caractere, pentru date calendaristice) folosite ============================================================ --

-- --------------- 3 functii matematice ------------------------- --
# media voturilor obtinute de un user per comentariu (rotunjita)
SELECT round(avg(comment.count_upvotes)) as avg_upvotes FROM (
	SELECT count(comment_has_upvote.comment_id) as count_upvotes FROM user
		LEFT JOIN comment on user.id = comment.user_id
		LEFT JOIN comment_has_upvote on comment.id = comment_has_upvote.comment_id
		WHERE user.id = 1
		GROUP BY comment.id, user.id
) comment;
# cate tag-uri are in medie un articol (floor)
select floor(avg(article.count_tags)) as avg_count_tags from (
	select count(article_has_tag.article_id) as count_tags from article
		left join article_has_tag on article.id = article_has_tag.article_id
		inner join tag on article_has_tag.tag_id = tag.id
		group by article.id
) article;
# cate comentarii are in medie un articol (ceil)
select ceil(avg(article.count_comments)) as avg_count_comments from (
	select count(comment.article_id) as count_comments from article
	left join comment on article.id = comment.article_id
    group by article.id
) article;

-- --------------- 3 functii de comparare ------------------------- --
# selectam articole similare cu articolul 1 (bazandu-ne pe tag-uri)
select * from article
	left join article_has_tag on article.id = article_has_tag.article_id
    where article_has_tag.tag_id in(
		select tag_id from article_has_tag where article_id = 1
    )
    group by article.id;
# selectam articole similare cu articolul 1, excluzand articolul 1
select * from article
	left join article_has_tag on article.id = article_has_tag.article_id
    where article_has_tag.tag_id in(
		select tag_id from article_has_tag where article_id = 1
    ) and article.id != 1
    group by article.id;
# selectam articole care au cel putin doua vizualizari
select * from article
	left join article_has_view on article.id = article_has_view.article_id
    group by article_has_view.article_id
    having count(article_has_view.article_id) >= 2;
# cati useri cu adresa de gmail am?
select count(id) as gmail_users from user
	where email like '%@gmail.com';

-- --------------- 3 functii de conditie ------------------------- --
# sortam articolele dupa numarul de vizualizari. In functie de caz, avem un summary text
select case
		when count(article_has_view.article_id) >= 3 then concat("Articol recomandat: ", article.title)
		when count(article_has_view.article_id) >= 2 then concat("Articol bun: ", article.title)
		else concat("Articol cu potential: ", article.title) 
        end as summary
	from article
	left join article_has_view on article.id = article_has_view.article_id
    group by article_has_view.article_id
    order by count(article_has_view.article_id) desc;
# daca un articol nu are comentarii, intoarce mesajul: fii primul care comenteaza
select ifnull(comment.text, "Fii primul care adauga un comentariu") as message from article
	left join comment on article.id = comment.article_id
    where article.id = 7;
# acelasi lucru folosind if
select if(comment.text is null, "Fii primul care adauga un comentariu", comment.text) as message from article
	left join comment on article.id = comment.article_id
    where article.id = 7;

-- --------------- 3 functii de string ------------------------- --
# intorc tag-urile in ordine alfabetica
select distinct value from tag order by ascii(value); -- asta imi intoarce alfabetic doar dupa prima litera :(
# 
select distinct value from tag order by ord(value); -- varianta corecta :)
# selectam numele utilizatorilor uppercase
select ucase(concat(firstname," ", lastname)) as ucase_user_name from user;

-- --------------- 3 functii calendaristice ------------------------- --
# inseram un articol care sa aiba o vechime de 5 zile
insert into article(title, text, user_id, created_at, updated_at) values
	("titlu articol inserat la linia 408", "text articol inserat la linia 408", 1, date_sub(now(), interval 5 day), date_sub(now(), interval 5 day));
# selectam titlurile de articole si vechimea in zile
select title, datediff(created_at, now()) as old_in_days from article;
# selectam articolele din luna curenta
select title from article where month(created_at) = month(now());
# selectam articole cu un anumit time format
select title, date_format(created_at, "%a, %d %M %Y") from article;

-- =============== crt 5 (minim 2 view) ============================================================ --
# ! sunt invocate la final de cerinta !
# selectam comentariile alaturi de autorul lor
CREATE VIEW comment_with_author AS
	SELECT comment.text, concat(substr(user.firstname, 1, 1), ". ", user.lastname) as name FROM COMMENT
		INNER JOIN user ON comment.user_id = user.id;
# selectam preview-uri la articole alaturi de numarul de vizualizari
CREATE VIEW article_preview_with_count_views AS
	SELECT article.text, user.firstname, user.lastname, count(article_has_view.article_id) as views FROM article
		INNER JOIN user ON article.user_id = user.id
        LEFT JOIN article_has_view ON article.id = article_has_view.article_id
        GROUP BY article_has_view.article_id;

select * FROM comment_with_author;
select * FROM article_preview_with_count_views;

-- =============== crt 6 (minim 3 functii) ============================================================ --
-- cream cateva coloane in plus
alter table comment add column count_votes int default 0 after article_id;
alter table comment add column comment_path varchar(255) default null;
alter table article add column computed_tags varchar(70) default null after user_id;
alter table user add column count_votes int default 0 after email;

# ! sunt invocate la final de cerinta !
# cate comentarii are un articol dat ca argument?
DELIMITER //
CREATE FUNCTION get_article_comments_count($article_id int) returns int
begin
	declare comments_count int;
	SELECT count(article_id) into comments_count FROM comment
		WHERE comment.article_id = $article_id;
	return comments_count;
end;
//
delimiter ;
# cate vizualizari are un articol dat ca argument?
delimiter //
CREATE FUNCTION get_article_views_count($article_id int) returns int
begin
	declare views_count int;
	SELECT count(article_id) into views_count FROM article_has_view
		WHERE article_has_view.article_id = $article_id;
	return views_count;
end;
//
delimiter ;
# utilizatorul x a votat comentariul y?
delimiter //
CREATE FUNCTION user_has_voted_comment($user_id int, $comment_id int) returns enum("true", "false")
begin
	declare has_upvoted varchar(5);
    declare count_records int;
	SELECT count(comment_has_upvote.user_id) into count_records FROM comment_has_upvote
		WHERE comment_has_upvote.user_id = $user_id AND comment_has_upvote.comment_id = $comment_id;
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
# care sunt cei mai votati 3 utilizatori in functie de comentarii?
DELIMITER //
CREATE PROCEDURE get_top_3_voted_users_by_comments(out pos1 varchar(50), out pos2 varchar(50), out pos3 varchar(50))
begin
	declare temp_users varchar(153);
	SELECT GROUP_CONCAT(r.user_name SEPARATOR '|') INTO temp_users FROM (
		SELECT concat(user.firstname, " ", user.lastname) as user_name FROM user
			LEFT JOIN comment ON user.id = comment.user_id
			LEFT JOIN comment_has_upvote ON comment.id = comment_has_upvote.comment_id
			GROUP BY user.id ORDER BY count(user.id) DESC LIMIT 3
	) r;
    set pos1 = substring(temp_users, 1, locate("|", temp_users)-1);
    set temp_users = substring(temp_users, locate("|", temp_users)+1);
    set pos2 = substring(temp_users, 1, locate("|", temp_users)-1);
    set temp_users = substring(temp_users, locate("|", temp_users)+1);
	set pos3 = substring(temp_users, 1);
    select pos1, pos2, pos3;
end
//
DELIMITER ;
call get_top_3_voted_users_by_comments(@pos1, @pos2, @pos3);
# cate comentarii are utilizatorul cu id-ul dat ca parametru?
DELIMITER //
CREATE PROCEDURE get_user_comments_count(in $user_id int, out $count_comments int)
begin
	SELECT count(comment.user_id) into $count_comments FROM comment
		WHERE comment.user_id = $user_id;
end;
//
DELIMITER ;
call get_user_comments_count(1, @count_comments);
select @count_comments;
# vreau o lista cu tag-urile unui articol dat, separate intre ele cu ', '
DELIMITER //
CREATE PROCEDURE get_article_tags(in $article_id int, out $tags varchar(255))
begin
	SELECT GROUP_CONCAT(tag.value SEPARATOR ', ') INTO $tags FROM article
		LEFT JOIN article_has_tag ON article.id = article_has_tag.article_id
		INNER JOIN tag ON article_has_tag.tag_id = tag.id
		WHERE article.id = $article_id;
	select $tags;
end;
//
DELIMITER ;
call get_article_tags(1, @tags);
-- =============== crt 6 (minim 3 cursori) ============================================================ --
# fac update de comment.count_votes bazandu-ma pe totalul voturilor 
# (pot obtine acelasi rezultat mai simplu prin subquery, dar voi folosi cursori)
delimiter //
create procedure update_comment_count_votes(in $comment_id int)
begin
	declare $hasMore enum('true', 'false') default "true";
    declare $loop_id int;
    declare $count_votes int default 0;
    
	declare c cursor for select comment_id from comment_has_upvote;
    declare continue handler for not found
    begin
		set $hasMore = "false";
    end;
    
    open c;
    lup: loop
		fetch c into $loop_id;
		if $hasMore = "false" then 
			leave lup;
		end if;
        if $loop_id = $comment_id then
			set $count_votes = $count_votes + 1;
		end if;
	end loop lup;
    close c;
    update comment set count_votes = $count_votes;
end;
//
delimiter ;
call update_comment_count_votes(1);
select * from comment where id = 1;

-- cream o coloana computed_tags in article
# update article.computed_tags cu tag-urile legate intre ele prin ', '
delimiter //
create procedure update_article_computed_tags(in $article_id int, out result varchar(255))
begin
	declare $hasMore enum('true', 'false') default "true";
    declare $concat_tags varchar(255) default null;
    declare $loop_tag varchar(25) default "";
    
	declare c cursor for select tag.value from article
		left join article_has_tag on article.id = article_has_tag.article_id
        inner join tag on article_has_tag.tag_id = tag.id
        where article.id = $article_id;
    declare continue handler for not found
    begin
		set $hasMore = "false";
    end;
    
    open c;
    lup: loop
		fetch c into $loop_tag;
		if $hasMore = "false" then 
			leave lup;
		end if;
		set $concat_tags = $loop_tag;
	end loop lup;
    close c;
    update article set computed_tags = $concat_tags;
    select $concat_tags;
end;
//
delimiter ;
call update_article_computed_tags(1, @computed_tags);
select * from article where id = 1;

# update user.count_votes - valoare computed la un anumit interval de timp
delimiter //
create procedure update_user_count_votes(in $user_id int)
begin
	declare $hasMore enum('true', 'false') default "true";
    declare $count_votes int default 0;
    declare $loop_vootes int;
    
	declare c cursor for select count(comment.id) from comment
		left join comment_has_upvote on comment.id = comment_has_upvote.comment_id
        where comment.user_id = $user_id
        group by comment.id;
    declare continue handler for not found
    begin
		set $hasMore = "false";
    end;
    
    open c;
    lup: loop
		fetch c into $loop_vootes;
		if $hasMore = "false" then 
			leave lup;
		end if;
        set $count_votes = $count_votes + $loop_vootes;
	end loop lup;
    close c;
    update user set count_votes = $count_votes;
end;
//
delimiter ;
call update_user_count_votes(1);
select * from user where id = 1;

-- =============== crt 6 (minim 3 triggeri) ============================================================ --
# actualizam automat user.count_votes, comment.count_votes
delimiter //
create trigger update_user_count_votes after insert on comment_has_upvote for each row
begin
	update comment set count_votes = (
		select count(comment_id) from comment_has_upvote
			where comment_id = new.comment_id
    ) where comment.id = new.comment_id;
    update user set count_votes = (
		select count(id) from comment_has_upvote
			inner join comment on comment_has_upvote.comment_id = comment.id
            where comment.user_id = (select user_id from comment where id = new.comment_id)
    );
end;
//
delimiter ;
update comment set count_votes = 0; -- pentru a evita orice confuzie cauzata de procedurile si functiile anterioare
update user set count_votes = 0;
select * from comment where id = 5; -- 0
insert into comment_has_upvote(comment_id, user_id) values
    (5, 9),
    (5, 10);-- am dat 2 voturi de la 2 useri diferiti
select * from comment where id = 5;

# voi restructura modul in care functioneaza tabela comentarii pentru a evita orice recursive select
# voi adauga o coloana comment_path care va avea valori pe modelul '1/2/3' 
# semnificand: actualul comentariu e reply la 3, care e reply la 2, care e reply la 1
delete from comment;

delimiter //
create trigger pre_set_comment_path before insert on comment for each row
begin
	declare $comment_path varchar(255);
	if !isnull(new.parent_id) then
		select concat_ws("/", comment_path, id) into $comment_path from comment where id = new.parent_id; -- din fericire concat_ws("/", null, x) returneaza x, nu /x
        set new.comment_path = $comment_path;
    end if;
end;
//
delimiter ;

# acum facem insert-uri de mai multe comentarii care sa constituie un thread multi-ramificat
set foreign_key_checks = 0;
insert into comment (id, text, user_id, parent_id, article_id) values
	(1,        "comentariu root", 1, null, 1),
    (2, "reply la comentariul 1", 2, 1, 1),
    (3, "reply la comentariul 2", 3, 2, 1),
    (4, "reply la comentariul 2", 4, 2, 1),
    (5, "reply la comentariul 4", 1, 4, 1);
insert into comment (id, text, user_id, parent_id, article_id) values
	(6, "comentariu care nu are legatura cu thread-ul", 1, null, 1),
    (7, "comentariu care nu are legatura cu thread-ul", 1, null, 1),
    (8, "comentariu care nu are legatura cu thread-ul", 1, null, 1),
    (9, "comentariu care nu are legatura cu thread-ul", 1, null, 1),
    (10, "comentariu care nu are legatura cu thread-ul", 2, null, 1),
    (11, "comentariu care nu are legatura cu thread-ul", 3, null, 1),
    (12, "comentariu care nu are legatura cu thread-ul", 4, null, 1),
    (13, "comentariu care nu are legatura cu thread-ul", 2, 12, 1); -- pentru acest insert de test dau jos foreign key check (il voi folosi mai apoi)... nu ma lasa in bulk insert
set foreign_key_checks = 1;

select * from comment;
# acum pot avea select-uri mai complexe, ca de exemplu: selecteaza-mi tot thread-ul pe care se afla comment cu id 3
select * from comment
	left join comment as tc on 
    comment.comment_path like concat(REGEXP_SUBSTR(tc.comment_path, "^[0-9]+"), "/%") -- intoarce x din sirul x/y/z sau x normal
    or comment.id = REGEXP_SUBSTR(tc.comment_path, "^[0-9]+") -- intorc si root comment, care nu ar fi fost alaturat prin prima clauza
	where tc.id = 3;
/*
	Ce am facut mai sus:
    -------------
    id:description
    -------------
    1:comment1                 |parent_id null, comment_path null
	  2:reply_to_comment1      |parent_id 1, comment_path 1
        3:reply_to_comment2	   |parent_id 2, comment_path 1/2
	  4:reply_to_comment1      |parent_id 1, comment_path 1
	5:comment2                 |parent_id null, comment_path null
*/

# atunci cand un user isi sterge contul, toate articolele lui vor fi preluate de user Anonim
# pot face un trigger pe comentarii ca atunci cand se sterg sa stearga si toate comentariile din thread
insert into user(id, firstname, lastname, email) values (9999, "anonim", "user", "xyz@gmail.com");
delimiter //
# e adevarat ca folosesc un before delete, care nu mi-ar asigura stergerea user-ului, dar.... mai mult nu pot face in mysql
# Daca am un after delete, ma blocheaza foreign-keys-urile... sa mai rezolve si baietii de la server :D
create trigger on_user_delete before delete on user for each row
begin
	update article set user_id = 9999 where user_id = old.id;
    update article_has_view set user_id = 9999 where user_id = old.id;
end;
//
delimiter ;
# atunci cand un user isi sterge contul, respectiv comentariile, 
# raspunsurile din thread la comentariul respectiv raman in suspensie. Pot genera erori. 
# Problema e ca am aflat acum ca 'on delete cascade' pe article nu declanseaza trigger de delete pe comment(on_comment_delete_clear_thread)
# o posibila solutie ar fi sa fac prin triggers: after delete user -> delete comment, after delete comment -> delete comment_thread, after delete article -> delete comment
# ba nu... am lasat mysql sa se ocupe de asta automat. Am o coloana comment.parent_id foreign key pe comment.id on delete cascade.
# atunci cand user se sterge, se sterge si comentariul in cascada, iar in cascada se sterg si comment.replies

select * from article;
delete from user where id = 1; -- Asta sunt eu..... Aici ies din scena :D
select * from article;
select * from comment;