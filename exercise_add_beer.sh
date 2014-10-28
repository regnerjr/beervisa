#!/usr/bin/env bash
# tests for add_beer api endpoint

test_add_beer_get(){
	echo
	echo "Testing add_beer_get"
	#get returns a list of dictionaries
	curl -s 0.0.0.0:8080/api/add_beer | grep -o 'Brown.*Lager.*Tripel'
	if [[ $? != 0 ]] ; then
		echo Get beers Default Failed
	fi

	curl -s 0.0.0.0:8080/api/add_beer/?order=glass_name | grep -o 'can.*tulip.*tulip'
	if [[ $? != 0 ]] ; then
		echo Get beers order_glass Failed
	fi

	curl -s 0.0.0.0:8080/api/add_beer/?order=name | grep -o 'Fat.*New.*PBR'
	if [[ $? != 0 ]] ; then
		echo Get beers order by name Failed
	fi

	curl -s 0.0.0.0:8080/api/add_beer/?order=abv | grep -o '3\.5.*5\.5.*7'
	if [[ $? != 0 ]] ; then
		echo Get beers order by abv Failed
	fi

	curl -s 0.0.0.0:8080/api/add_beer/?order=overall | grep -o '10.*20.*20'
	if [[ $? != 0 ]] ; then
		echo Get beers order by overall Failed
	fi

	curl -s 0.0.0.0:8080/api/add_beer/?order=calories | grep -o '80.*100.*120'
	if [[ $? != 0 ]] ; then
		echo Get beers order by calories Failed
	fi

	curl -s 0.0.0.0:8080/api/add_beer/?order=ibu | grep -o '40.*60.*80'
	if [[ $? != 0 ]] ; then
		echo Get beers order by ibu Failed
	fi

}

test_add_beer_post(){
	echo
	echo "Testing add_beer_post"
	curl -c add_beer_cookie -b add_beer_cookie \
		-d "name=Guiness&ibu=50&calories=80&abv=5%&style=Stout&location=Ireland&glass=pint"\
		0.0.0.0:8080/api/add_beer 
	sqlite3 beer.db 'select name from beer where name is "Guiness";' | grep -o 'Guiness'
	if [[ $? != 0 ]] ; then 
		echo "Testing add_beer POST failed"
	fi
	
	#this one should fail since I can only add one beer per day
	curl -v -c add_beer_cookie -b add_beer_cookie \
		-d "name=Molson&ibu=35&calories=70&abv=4%&style=Lager&location=Canada&glass=pint" \
		0.0.0.0:8080/api/add_beer 2>&1 | grep -o 'wait until tomorrow'
	if [[ $? != 0 ]] ; then 
		echo "Testing add_beer POST 2 in one day failed"
	fi
}
clean_beer_list(){
	sqlite3 beer.db 'delete from glasses where id > 0;'
	sqlite3 beer.db 'insert into glasses (id,glass_name) values (1,"can");'
	sqlite3 beer.db 'insert into glasses (id,glass_name) values (2,"pint");'
	sqlite3 beer.db 'insert into glasses (id,glass_name) values (3,"tulip");'

	sqlite3 beer.db 'delete from beer where id > 0'
	sqlite3 beer.db 'insert into beer (ibu, calories, abv, style, location, glass_id, name, overall) values (80, 120, "7%", "Tripel", "Colorado", 3, "New Belgium Tripel", 20)'
	sqlite3 beer.db 'insert into beer (ibu, calories, abv, style, location, glass_id, name, overall) values (60, 100, "5.5%", "Brown Ale", "Colorado", 3, "Fat Tire", 20)'
	sqlite3 beer.db 'insert into beer (ibu, calories, abv, style, location, glass_id, name, overall) values (40, 80, "3.5%", "Lager", "Milwaukee", 1, "PBR", 10)'
	
	sqlite3 beer.db 'delete from users where id> 0'
	curl -v -F usr=add_beer_tester -F passwd=add_beer_tester -F email=add_beer@test.com 0.0.0.0:8080/api/add_user &>/dev/null #create new user
	curl -v -c add_beer_cookie -F usr=add_beer_tester -F passwd=add_beer_tester 0.0.0.0:8080/api/login &>/dev/null #login and create a cookie
}

########## MAIN ##########
clean_beer_list

test_add_beer_get
test_add_beer_post

rm add_beer_cookie