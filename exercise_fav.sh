#!/usr/bin/env bash

test_favorite_get(){
	echo
	echo "Testing fav GET"
	curl -v 0.0.0.0:8080/api/fav 2>&1 | grep -o 'Bock.*Ale'
 	if [[ $? != 0 ]] ; then
 		echo Get all favorites Failed
	fi
	curl -v 0.0.0.0:8080/api/fav/?order=usr 2>&1 | grep -o 'aaa.*zzz'
 	if [[ $? != 0 ]] ; then
 		echo get_favs order by user failed
	fi

	curl -v 0.0.0.0:8080/api/fav/?user=zzz 2>&1 | grep aaa
 	if [[ $? == 0 ]] ; then
 		echo Get favorites of specific user failed 
	fi
	
	curl -v 0.0.0.0:8080/api/fav/?user=zzz 2>&1 | grep -o 'Awesome'
 	if [[ $? != 0 ]] ; then
 		echo Get favorites of specific user, and sorted failed 
	fi
}

test_favorite_post(){
	echo
	echo "Testing fav POST"
	#add a test user
	curl -v -F usr=fav_tester -F passwd=fav_tester -F email=fav@test.com 0.0.0.0:8080/api/add_user &>/dev/null
	#log in 
	rm fav_cookie &>/dev/null
	curl -v -c fav_cookie -F usr=fav_tester -F passwd=fav_tester 0.0.0.0:8080/api/login &>/dev/null
	#attempt to fav the beer
	curl -v -c fav_cookie -b fav_cookie -F beer=AwesomeBock 0.0.0.0:8080/api/fav &>/dev/null
	#check the db to ensure that the fav worked.
	sqlite3 beer.db 'select name,usr from favorites inner join beer on favorites.beer_id = beer.id inner join users on users.id = favorites.user_id;' | grep -o 'Awesome.*fav_tester'
 	if [[ $? != 0 ]] ; then
 		echo "Add favorite, normal case" 
	fi	
	rm fav_cookie
}

test_favorite_delete(){
	echo
	echo "Testing fav DELETE"
	#create new user
	curl -F usr=fav_delete_tester -F passwd=fav_delete_tester -F email=fav_delete@test.com 0.0.0.0:8080/api/add_user &>/dev/null
	#log in 
	curl -c fav_delete_cookie -F usr=fav_delete_tester -F passwd=fav_delete_tester 0.0.0.0:8080/api/login &>/dev/null
	#attempt to fav the beer
	curl -v -c fav_delete_cookie -b fav_delete_cookie -F beer=MyFarmhouseAle 0.0.0.0:8080/api/fav &>/dev/null
	#attempt to unfavorite the beer
	curl -v -c fav_delete_cookie -b fav_delete_cookie 0.0.0.0:8080/api/fav/?beer=MyFarmhouseAle -X DELETE &>/dev/null
	#check the db to ensure deleting the favorite worked.
	sqlite3 beer.db 'select name,usr from favorites inner join beer on favorites.beer_id = beer.id inner join users on users.id = favorites.user_id;' | grep -o 'Awesome.*fav_delete_tester'
 	if [[ $? == 0 ]] ; then
 		echo "Delete Failed" 
	fi
}



clean_db(){
# clean the datbase for testing
sqlite3 beer.db 'delete from favorites where user_id > 0;'
sqlite3 beer.db 'delete from users where id > 0;'
sqlite3 beer.db 'delete from beer where id > 0;'

#put some test data in there
sqlite3 beer.db 'insert into users (id, usr, passwd, email, role) values (1, "zzz", "zzz", "zzz@test.com", 1);'
sqlite3 beer.db 'insert into users (id, usr, passwd, email, role) values (2, "aaa", "aaa", "aaa@test.com", 1);'

sqlite3 beer.db 'insert into beer (id,ibu, calories, abv, style, location, glass_id, name, overall) values (1, 100, 70, 5, "Farmhouse", "My House", 1, "MyFarmhouseAle", 0.0);'
sqlite3 beer.db 'insert into beer (id,ibu, calories, abv, style, location, glass_id, name, overall) values (2, 90, 60, 4.5, "Bock", "Texas", 1, "AwesomeBock", 0.0);'

sqlite3 beer.db 'insert into favorites (user_id, beer_id) values (1,2);'
sqlite3 beer.db 'insert into favorites (user_id, beer_id) values (2,1);'
}

####### MAIN ########

clean_db

test_favorite_get

test_favorite_post

test_favorite_delete

rm fav_delete_cookie
