test_add_user_get(){
	echo
	echo "Testing add_user get"
	curl -v 0.0.0.0:8080/api/add_user 2>&1 | grep -o 'test_name.*zzz'
	if [[ $? != 0 ]] ; then
		echo add_user_get failed
	fi
	curl -v 0.0.0.0:8080/api/add_user/?order=email 2>&1 | grep -o 'a@test\.com.*test@test\.com'
	if [[ $? != 0 ]] ; then
		echo add_user_sort_email failed
	fi
	curl -v 0.0.0.0:8080/api/add_user/?order=unsupported 2>&1 | grep -o "could not complete your query"
	if [[ $? != 0 ]] ; then
		echo add_user_sort_unsupported failed
	fi
}
test_add_user_post(){
	echo
	echo "Testing add_user POST"
	# Start with post so we know we have at least one record
	curl -v -F usr=test_name -F passwd=test_name -F email=test@test.com 0.0.0.0:8080/api/add_user 2>&1 | \
		tr '\n' ' ' | grep -o '303 See Other'
	if [[ $? != 0 ]] ; then
		echo add_user POST failed
    fi
}
test_add_user_post_bad_params(){
	echo
	echo "Testing add_user POST with bad params"
	#test empty username
	curl -v -F usr="" -F passwd=vvvv -F email=vvv@vvv.com 0.0.0.0:8080/api/add_user 2>&1 | \
		grep -o 'Username.*empty'
	if [[ $? != 0 ]] ; then
		echo add_user empty username failed
	fi
	#test empty password
 	curl -v -F usr="vvv" -F passwd= -F email=vvv@vvv.com 0.0.0.0:8080/api/add_user 2>&1 | \
 		grep -o 'Password.*empty'
 	if [[ $? != 0 ]] ; then
 		echo add_user empty password failed
	fi
	#test empyt email
 	curl -v -F usr=vvv -F passwd=vvv -F email= 0.0.0.0:8080/api/add_user 2>&1 | \
 		grep -o 'Email.*empty'
 	if [[ $? != 0 ]] ; then
 		echo add_user empty email failed
	fi
}
test_add_user_put(){
	echo
	echo "Testing add_user PUT"
	#must log_in and store a cookie to update a user record
	#logging in as zzz, save login to zzz_cookie
	rm zzz_cookie &>/dev/null #remove cookie if we already have one
	#test our account
	curl -v -c zzz_cookie -b zzz_cookie -F usr=zzz -F passwd=zzz 0.0.0.0:8080/api/login &>/dev/null
	curl -X PUT -v -c zzz_cookie -b zzz_cookie -F usr=zzz -F passwd=zzz -F email=zzz@test.com 0.0.0.0:8080/api/add_user 2>&1 | grep -o '200 OK'
 	if [[ $? != 0 ]] ; then
 		echo user add PUT, to update Email failed.
	fi
	#test an account that we do not own
	curl -X PUT -v -c zzz_cookie -b zzz_cookie -F usr=test_user -F passwd=test -F email=zzz@test.com \
		0.0.0.0:8080/api/add_user 2>&1 | grep -o 'Session user must match'
 	if [[ $? != 0 ]] ; then
 		echo add_user PUT, update an un owned account failed.
	fi

	curl -X PUT -v -c zzz_cookie -b zzz_cookie -F usr=zzz_changed -F passwd=zzz -F email=zzz@test.com \
		0.0.0.0:8080/api/add_user 2>&1 | grep -o '200 OK'
 	if [[ $? != 0 ]] ; then
 		echo user add PUT, to update username failed.
	fi
	curl -X PUT -v -c zzz_cookie -b zzz_cookie -F usr=zzz_changed -F passwd=zzz_changed -F email=zzz@test.com \
		0.0.0.0:8080/api/add_user 2>&1 | grep -o 'Session user must match'
 	if [[ $? != 0 ]] ; then
 		echo user add PUT, update password, of account whose username we just changed FAILED?
	fi
}
test_add_user_delete(){
	echo
	echo "Testing add_user DELETE"
	#test deletion of our own account
	rm zzz_cookie
	sqlite3 beer.db 'delete from users where usr="zzz_changed"'
	curl -v -F usr=zzz_changed -F passwd=zzz_changed -F email=zzz_changed@test.com 0.0.0.0:8080/api/add_user &>/dev/null
	curl -v -c zzz_cookie -b zzz_cookie -F usr=zzz_changed -F passwd=zzz_changed 0.0.0.0:8080/api/login &>/dev/null
	curl -X DELETE -v -c zzz_cookie -b zzz_cookie \
		0.0.0.0:8080/api/add_user 2>&1 | grep -o '303 See Other'
 	if [[ $? != 0 ]] ; then
 		echo add_user DELETE failed
	fi
	
}

#################### MAIN #####################
# Exercise the add_user api
#remove the test user from the database if they exist
sqlite3 beer.db 'delete from users where usr="test_name";'
sqlite3 beer.db 'delete from users where usr="zzz";'
sqlite3 beer.db 'delete from users where usr="vvv";'
sqlite3 beer.db 'delete from users where usr="test_user";'
sqlite3 beer.db 'delete from users where usr="zzz_changed";'
#Add test user account
test_add_user_post

#create a second account so we can test the sorting
curl -v -F usr=zzz -F passwd=zzz -F email=a@test.com 0.0.0.0:8080/api/add_user &>/dev/null
 
test_add_user_get #returned list of users should be sorted by usr by default

test_add_user_post_bad_params #test empty usr,passwd,email

test_add_user_put #attempts to update a logged in account, and someone elses account

test_add_user_delete

rm zzz_cookie
