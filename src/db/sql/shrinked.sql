drop database if exists myDatabase;
CREATE DATABASE myDatabase;
USE myDatabase;

CREATE TABLE _user (
	id int primary key auto_increment,
    firstname varchar(25),
    lastname varchar(25),
    email varchar(50) not null,
    count_votes int default 0,
	created_at timestamp default now(),
    updated_at timestamp default now()
);

CREATE TABLE article (
	id int primary key auto_increment,
    title varchar(180) not null,
    text text not null,
    user_id int not null,
    computed_tags varchar(70) default null,
    created_at timestamp default now(),
    updated_at timestamp default now(),
    
    FOREIGN KEY(user_id) REFERENCES _user(id)
);

CREATE TABLE tag (
	id int primary key auto_increment,
    value varchar(25)
);

CREATE TABLE article_has_tag (
	article_id int,
    tag_id int,
    
    primary key(article_id, tag_id),
	foreign key(article_id) references article(id),
    foreign key(tag_id) references tag(id)
);

CREATE TABLE _comment (
	id int primary key auto_increment,
    text tinytext not null,
    user_id int not null,
    parent_id int default null, -- adaugat prin alter table la randul 123
    article_id int not null,
    count_votes int default 0,
	comment_path varchar(255) default null,
	created_at timestamp default now(),
    updated_at timestamp default now(),
    
    CONSTRAINT author FOREIGN KEY(user_id) REFERENCES _user(id) ON DELETE CASCADE,
	CONSTRAINT reply_to FOREIGN KEY(parent_id) REFERENCES _comment(id) ON DELETE CASCADE, -- adaugat prin alter table la randul 124
    CONSTRAINT article FOREIGN KEY(article_id) REFERENCES article(id) ON DELETE CASCADE
);

CREATE TABLE comment_has_upvote (
	comment_id int,
    user_id int,
    
    primary key(comment_id, user_id),
    foreign key(comment_id) references _comment(id) on delete cascade,
    foreign key(user_id) references _user(id) on delete cascade
);

CREATE TABLE article_has_view (
	article_id int not null,
    -- session_id varchar(90) not null,
    user_id int default null, -- nullable, nu necesita autentificare
    ip varchar(20) not null,
    -- agent varchar(30) not null,
	created_at timestamp default now(),
    
    primary key(article_id, ip),
    foreign key(article_id) references article(id) on delete cascade,-- va fi considerat view doar daca vine de la un IP diferit
    FOREIGN KEY(user_id) REFERENCES _user(id)
);