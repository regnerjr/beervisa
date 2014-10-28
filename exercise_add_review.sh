#!/usr/bin/env bash

test_add_review_get(){
	echo 
	echo "Testing add_review_get"
	curl -s 0.0.0.0:8080/api/add_review | grep -o 'AwesomeBock.*Blue.*MyFarmhouseAle.*MyFarmhouseAle'
	if [[ $? != 0 ]] ; then
		echo Get all reviews Failed
	fi
	curl -s 0.0.0.0:8080/api/add_review/?order=aroma 2>&1 | grep -o 'MyFarmhouse.*Blue.*MyFarmhouse.*Awesome'
	if [[ $? != 0 ]] ; then
		echo Get all reviews order IBU Failed
	fi
	curl -s 0.0.0.0:8080/api/add_review/?which=MyFarmhouseAle 2>&1 | grep -E '(AwesomeBock|Blue Moon)' &>/dev/null #should not return either of the other beers
	if [[ $? == 0 ]] ; then
		echo "Get review for MyFarmhouseAle Failed"
	fi
	curl -s "0.0.0.0:8080/api/add_review/?order=aroma&which=MyFarmhouseAle" &> aroma_ordered_farmhouse_reviews ;
	grep -E '(Blue Moon|Awesome)' aroma_ordered_farmhouse_reviews ; if [[ $? == 0 ]] ; then echo "Get review beer order failed" ; exit; fi
	grep -o 'aroma...1.*aroma...5' aroma_ordered_farmhouse_reviews ; if [[ $? != 0 ]] ; then	echo Get review beer and order Failed;	exit; fi
	rm aroma_ordered_farmhouse_reviews
	
	curl -s 0.0.0.0:8080/api/add_review/?which=Unknown | grep -o 'was not found'
	if [[ $? != 0 ]] ; then
		echo "Get review for Unknown Failed"
	fi
}

test_add_review_post(){
	echo
	echo Testing add_review_post
	#create a new user
	curl -F usr=add_review_tester -F passwd=add_review_tester -F email=add_review@test.com 0.0.0.0:8080/api/add_user &>/dev/null
	#log in 
	curl -c add_review_cookie -F usr=add_review_tester -F passwd=add_review_tester 0.0.0.0:8080/api/login &>/dev/null
	#add a new review
	curl -s -c add_review_cookie -b add_review_cookie -F beer=Unknown -F aroma=4 -F appearance=4 -F taste=4 -F palate=4 -F bottle_style=4 0.0.0.0:8080/api/add_review | grep 'not found' #Unknown beer shoud be not found
	curl -s -c add_review_cookie -b add_review_cookie -F beer=MyFarmhouseAle -F aroma=4 -F appearance=4 -F taste=4 -F palate=4 -F bottle_style=4 0.0.0.0:8080/api/add_review
	# check the database for our new review from reviewer id = 3. 
	sqlite3 beer.db 'select * from review inner join users on users.id = review.reviewer where users.usr = "add_review_tester"' | grep -o -E '^[^|]\|4.4.4.4'
}

test_add_review_put(){
	echo
	echo Testing add_review PUT
	review_id=$(sqlite3 beer.db 'select review.id from review inner join users on users.id = review.reviewer where users.usr = "add_review_tester"')
	BeerName=MyFarmhouseAle
	curl -s -c add_review_cookie -b add_review_cookie -F review_id=$review_id -F beer=$BeerName -F aroma=4 -F appearance=4 -F taste=10 -F palate=4 -F bottle_style=4 -X PUT 0.0.0.0:8080/api/add_review
	sqlite3 beer.db "select * from review where id is $review_id" | grep -E '^[^|]+\|4.4.10.4.4' ; if [[ $? != 0 ]] ; then echo "Failed add_review (initial) PUT" ; exit ; fi
	# Ensure that the review was properly updated when we call put
	sqlite3 beer.db "select overall from beer where name is \"$BeerName\"" | grep -E '13' ; if [[ $? != 0 ]] ; then echo "Failed add_review (update to 13) PUT" ; exit ; fi

	echo "got here"
	curl -s -c add_review_cookie -b add_review_cookie -F review_id=$review_id -F beer=Unknown -F aroma=4 -F appearance=4 -F taste=7 -F palate=4 -F bottle_style=4 -X PUT 0.0.0.0:8080/api/add_review | \
		grep "Unknown" ;if [[ $? != 0 ]] ; then echo "Failed add_review (Unknown) PUT" ; exit ; fi

	review_id=1000 #probably an invalid id
	curl -s -c add_review_cookie -b add_review_cookie -F review_id=$review_id -F beer=Unknown -F aroma=4 -F appearance=4 -F taste=7 -F palate=4 -F bottle_style=4 -X PUT 0.0.0.0:8080/api/add_review &>/dev/null
	sqlite3 beer.db "select * from review where id is $review_id" | grep -o 'Unknown' ; if [[ $? == 0 ]] ; then echo "Something went wrong when updated bogus id review" ; exit; fi

}

test_add_review_for_same_beer_same_day(){
	curl -s -c add_review_cookie -b add_review_cookie -F beer=MyFarmhouseAle -F aroma=4 -F appearance=4 -F taste=4 -F palate=4 -F bottle_style=4 0.0.0.0:8080/api/add_review |\
		grep -o 'at least a week' ; if [[ $? != 0 ]] ; then echo "Failed add same review less than 1 week POST" ; exit ; fi
}

test_add_review_delete(){
	echo 
	echo Testing add_review DELETE
}

clean_db(){
# clean the datbase for testing
sqlite3 beer.db 'delete from review where id > 0;'
sqlite3 beer.db 'delete from users where id > 0;'
sqlite3 beer.db 'delete from beer where id > 0;'
sqlite3 beer.db 'delete from week_review;'

#put some test data in there
sqlite3 beer.db 'insert into users (id, usr, passwd, email, role, last_beer) values (1, "zzz", "zzz", "zzz@test.com", 1, "2014-06-15");'
sqlite3 beer.db 'insert into users (id, usr, passwd, email, role, last_beer) values (2, "aaa", "aaa", "aaa@test.com", 1, "2014-06-20");'

sqlite3 beer.db 'insert into beer (id,ibu, calories, abv, style, location, glass_id, name, overall) values (1, 100, 70, 5, "Farmhouse", "My House", 1, "MyFarmhouseAle", 0.0);'
sqlite3 beer.db 'insert into beer (id,ibu, calories, abv, style, location, glass_id, name, overall) values (2, 90, 60, 4.5, "Bock", "Texas", 1, "AwesomeBock", 0.0);'
sqlite3 beer.db 'insert into beer (id,ibu, calories, abv, style, location, glass_id, name, overall) values (3, 80, 80, 4.0, "Wheat", "Colorado", 1, "Blue Moon", 0.0);'

sqlite3 beer.db 'insert into review (id, aroma, appearance, taste, palate, bottle_style, beer, reviewer) values (1, 1, 2, 3, 4, 5, 1, 1);'
sqlite3 beer.db 'insert into review (id, aroma, appearance, taste, palate, bottle_style, beer, reviewer) values (2, 5, 4, 7, 4, 5, 1, 2);'
sqlite3 beer.db 'insert into review (id, aroma, appearance, taste, palate, bottle_style, beer, reviewer) values (3, 5, 4, 7, 4, 5, 2, 2);'
sqlite3 beer.db 'insert into review (id, aroma, appearance, taste, palate, bottle_style, beer, reviewer) values (4, 3, 3, 3, 3, 3, 3, 1);'

}

########## MAIN ##########
clean_db
sqlite3 beer.db	'select * from week_review'
test_add_review_get
test_add_review_post
test_add_review_put
test_add_review_for_same_beer_same_day
test_add_review_delete
rm add_review_cookie