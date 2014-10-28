# Beervisa - Where Corvisa goes to talk about beer

### Dependencies
I was given the choice between Python 2.5 and Python 3.4. After some exploration
I settled on Python2.5 since it seemed a bit more widely supported.

After considering Flask and Django I found that web.py was a good
match for my level of experience and the way I think about the web.

Web.py can be found on Github at https://github.com/webpy/webpy

I also needed to use a related module to do the password cryptography.
I found webpy-modules on Github at
https://github.com/PetrHoracek/webpy-modules. A few modifications were made to
this module to get it working with my setup. So I suggest using the version of
it included in this zip.

I am also using sqlite3 to manage the database for this project. I am using the
pysqlite ORM (version 2.6.3) to talk to the database. The source is included in
this zip, or it can be downloaded from https://pypi.python.org/pypi/pysqlite.

### Local Setup
You should have python2.5 already installed on your machine.
    unzip <this_package>.zip # probably already done
    cd <this_package> # also probably already done

Launch the beervisa.py using your version of python, it should pick up the
dependencies which were included in this zip
    python2.5 beervisa.py

This launches the webserver on 0.0.0.0:8080. Navigate to that address in your
browser and you will see the beervisa main page.

Create yourself a new account using the New Account link, then log in.
Once you are logged in you will have a Cookie which can be used to perform
actions based on your user account.

(The API can also be accessed through curl, examples of this can be found in
the tests.

## API endpoints

### /api/add_user
	GET : Get the user records
	- parameters
		None
	- returns
		A list of user dictionaries, [{usr: Bill, email: bill@excelent.com },{usr: Ted, email: ted@adventure.com},...]
	Note: Users are returned default ordered by username, to order by email call
	/api/add_user/?order=email  You may also want to return a list ordered by last_beer.

	POST : Creates a new user record
	- parameters
		usr = A username to be registered (string)
		passwd = the password to be associated with the user (string)
		email = the email to associate with the user (string)

	PUT : Update the currently logged in account
	- parameters
		cookie = The cookie of the currently logged in user, the account to update (cookie)
		usr = The updated username (string)
		passwd = The updated password (string)
		email = The updated email (string)

	DELETE : Deletes the record of the currently logged in user
	- parameters
		The cookie of the currently logged in user (cookie)

### /api/login
	POST : Used for logging in a user that is already created in the system, returns a cookie with the logged_in property set to true.
	- parameters
		usr = a registered username (string)
		passwd = a registered user's password (string)

### /api/add_glass
	GET : Returns the current list of glasses
	- parameters
		None
	POST : Adds a new glass to the database
	- parameters
		name = Name of the glass to add
	PUT : Updates the glass name based on the ID given
	- parameters
		id = ID of glass to change
		glass_name = The corrected name of the glass
	DELETE : Removes the named glass from the list
	- parameters
		name = Name of glass to remove

### /api/add_beer
	GET : Get the current list of beers
	- parameters
		None
	- returns
		A list of beer dictionaries [{name:name_beer1, attr:attribute1,...},{name:beer2, attr:attribute2},...]
		Attributes which are returned are 'style','glass_name','name','abv','overall','calories','ibu'
	Note: Beers are returned sorted by style by default, To select a different sorting use /api/add_beer/?order=attribute

	POST : Adds a new beer to the collection
	- parameters
		cookie = You must be logged in to enter a beer, (This permits the one beer per day rule.)
		name = The name of the beer to add (string)
		ibu = The IBUs of the beer being added (int)
		calories = The calories of the beer being added (int)
		abv = The abv of the beer being added (string)
		style = The style of the beer being added (string)
		location = The location of the brewery where this beer is made (string)
		glass = The name of the glass to enjoy this beer with (glass name: must be in the list returned from /api/add_glass)

	PUT : Updates an existing beer
	- parameters
		id = The id of the record in the beer table which you would like to update (int)
		name = The name of the beer to add (string)
		ibu = The IBUs of the beer being added (int)
		calories = The calories of the beer being added (int)
		abv = The abv of the beer being added (string)
		style = The style of the beer being added (string)
		location = The location of the brewery where this beer is made (string)
		glass = The name of the glass to enjoy this beer with (glass name: must be in the list returned from /api/add_glass)


	DELETE : Deletes a beer by ID
	- parameters
		id = The ID of the beer to delete (int)

### /api/add_review
	GET : Gets a list of current reviews
	-parameters
		order = How you would like the results ordered (string)
					defaults to sorting by the beer name, but any of the returned parameters are available
		which = Which beer to retrieve reviews for (string)
					default is all
	-returns
		A list of review dictionaries, [{},{},...,{}]
	Note: Reviews returned are sorted by "style" by default, to order by a
	different parameter call /api/add_review/?order=<parameter> Available
	parameters are [usr,email,beer,style,aroma,appearance,taste,palate,bottle_style,overall]

	POST :
	-parameters
		cookie = The cookie of the currently logged in user, used to assign a reviewer (cookie)
		aroma = The aroma rating (int)
		appearance = The appearance rating (int)
		taste = The appearance rating (int)
		palate = The palate rating (int)
		bottle_style = The rating of the brand styling (int)
		beer = The name of the beer under review (string)

	PUT :
	-parameters
		cookie = The cookie of the currently logged in user, used to assign a reviewer (cookie)
		id = The ID of the review to update (int)
		aroma = The aroma rating (int)
		appearance = The appearance rating (int)
		taste = The appearance rating (int)
		palate = The palate rating (int)
		bottle_style = The rating of the brand styling (int)
		beer = The name of the beer under review (string)

	DELETE :
	-parameters
		cookie = The cookie of the currently logged in user, used to ensure the
		         review that is being deleted is owned by the current user. (cookie)
		id = The ID of the review to delete (int)

### /api/fav
	GET : Get favorites list
	-parameters
		usr - Requests only the favorites for a specific user
		order - Requests that the returned list is sorted by user_name
	-returns
		A list of dictionaries containing usernames and beer names.
		The default sorting is by beer name.

	POST :
	-parameters
		cookie - Logged in cookie, this is how we contol which user the favorite is added to (cookie)
		beer - Name of the beer to favorite, must already be in the database. (string)

	PUT : No put is available, nothing to be updated.

	DELETE :
	-parameters
		cookie - Logged in cookie (cookie)
		name - Name of beer to remove from favorites, (needs to be sent as part of the uri)
			i.e. curl -b cookie example.com/api/fav/?beer=NoLongerFavorite -X DELETE
