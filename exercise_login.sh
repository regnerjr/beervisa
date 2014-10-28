#!/usr/bin/env bash

#Exercise the login methods.

#Test Get,
# should redirect us to the homepage
test_login_get(){
	echo
	echo "Testing login get"
	curl -v 0.0.0.0:8080/api/login 2>&1 | grep -o '< HTTP/1.1 303 See Other'
	if [[ $? != 0 ]] ; then
		echo test_login_get failed
	fi
}

# Test POST with good credentials, should log us in, and move us to the user_home
test_post_good(){
	echo
	echo "Test login POST"
	curl -v -c zzz_cookie -F usr=zzz -F passwd=zzz 0.0.0.0:8080/api/login 2>&1 | tr '\n' ' ' | grep -o '303.*user_home'
	if [[ $? != 0 ]] ; then
		echo test_login_post_good failed
	fi
}
# Test POST with Bogus credentials, should return sensible error
test_post_bogus_password(){
	echo
	echo "Testing login bad params"
	curl -v -c bogus_cookie -F usr=zzz -F passwd=bogus 0.0.0.0:8080/api/login 2>&1 | grep -o 'password.* was incorrect'
	if [[ $? != 0 ]] ; then
		echo test_login_post_bogus_password failed
	fi
}
test_post_bogus_username(){
	echo 
	echo "Testing login bad params"
	curl -v -c bogus_cookie -F usr=blarg_I_dont_exist -F passwd=bogus 0.0.0.0:8080/api/login 2>&1 | grep -o 'user name.* not found'
	if [[ $? != 0 ]] ; then
		echo test_login_post_bogus_username failed
	fi
}


################ MAIN #############
test_login_get

test_post_good

test_post_bogus_password

test_post_bogus_username

rm bogus_cookie
rm zzz_cookie
