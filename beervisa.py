import sys
import datetime
import sqlite3
import web #main web.py module
import webmod #the module containing the auth stuff
from webmod import auth #the auth stuff
import pysqlite #for the sqlite

db = web.database(dbn='sqlite', db='beer.db')

# add the html template folder
render = web.template.render("templates/")
# set up endpoints
urls = (
        '/'              , 'index'     ,
        '/new_user'      , 'new_user'  ,
        '/user_home'     , 'user_home' ,
        '/logout'        , 'logout'    ,
        '/api/add_user'  , 'add_user'  ,
        '/api/add_user/?', 'add_user'  ,
        '/api/login'     , 'login'     ,
        '/api/add_glass' , 'add_glass' ,
        '/api/add_beer'  , 'add_beer'  ,
        '/api/add_beer/?', 'add_beer'  ,
        '/api/add_review', 'add_review',
        '/api/add_review/?','add_review',
        '/api/fav'       , 'fav'       ,
        '/api/fav/?'     , 'fav'
        )

web.config.debug = False #toggles html, error pages
app = web.application(urls, locals())

login_fail = True  #assume not logged in
# set up user session to manage cookies and logins
session = web.session.Session(app, web.session.DiskStore('sessions'), initializer={'logged_in': False, 'usr': ""})
auth = webmod.auth.Auth(session, db, lgn_pg='/login')
crypt = webmod.auth.Crypt()

class index:
    def GET(self):
        beers = db.select('beer').list()
        reviews = db.query('select usr, name, location, style, overall from review inner join beer on review.beer = beer.id inner join users on users.id=review.reviewer').list()
        return render.index(beers, session, reviews)

class new_user:
    def GET(self):
        return render.new_user()

class user_home:
    def GET(self):
        if not session.logged_in:
            raise web.seeother('/')
        # get the users reviews
        user_id = db.select('users', what='id', where="usr is \"%s\"" % session.usr).list()[0].id
        reviews = db.select('review', where="reviewer is " + "%d" % user_id)
        beers   = db.select('beer', what='name').list()
        # get the list of glasses
        glasses = db.select('glasses', what='glass_name').list()
        return render.user_home(session.usr, reviews, glasses, beers)

class logout:
    def GET(self):
        auth.logout()
        session.logged_in = False
        session.usr = ""
        raise web.seeother('/')

#***** API Methods *****#
class add_usner:
    def GET(self):
        i = web.input(order='usr')
        try:
            users_list = db.select('users', what='usr,email', order=i.order).list()
        except sqlite3.OperationalError:
            return "could not complete your query, Probably an unsupported ordering was requested\n"
        return users_list

    def POST(self):
        i = web.input()
        if i.usr == "":
            return render.error("Username can not be empty")
        if i.passwd == "":
            return render.error("Password can not be empty")
        if str(i.email) == "":
            return render.error("Email can not be empty")
        pass_crypt = crypt.encrypt(i.passwd)
        try:
            db.insert('users', usr=i.usr, passwd=pass_crypt, email=i.email, role=1)
        except sqlite3.IntegrityError, KeyError:
            return render.error(sys.exc_value)
        raise web.seeother('/')

    def PUT(self):
        i = web.input()
        pass_crypt = crypt.encrypt(i.passwd)
        if session.logged_in:
            try:
                user = db.select('users', what="id,usr", where="usr is \"%s\"" % session.usr).list()[0]
            except IndexError:
                return render.error("Session User no longer in the database. Try logging out and back in.")
            if user.usr == i.usr:
                try:
                    records_changed = db.update('users', where="id is %d" % int(user.id) , usr=i.usr, email=i.email, passwd=pass_crypt, role=1)
                except sqlite3.IntegrityError, KeyError:
                    return render.error(sys.exc_value)
                return records_changed
            else:
                return render.error("Session user must match the account you are trying to update")
        raise web.seeother('/')

    def DELETE(self):
        # only the user with the current logged in name should be able to delete their own user record
        if session.usr:
            db.delete('users', where="usr is " + "\"%s\"" % session.usr)
        raise web.seeother('/')

class login:
    def GET(self):
        raise web.seeother('/')

    def POST(self):
        i = web.input()
        try:
            auth.login(i.usr, i.passwd)
            # if login passes set login_fail to true, and redirrect to user_home.
            login_fail = False
            session.logged_in = True
            session.usr = i.usr
            raise web.seeother('/user_home')
        except webmod.auth.WrongPassword, WrongPassword:
            login_fail = True
            return render.error("The password you entered was incorrect")
        except webmod.auth.UserNotFound, UserNotFound:
            login_fail = True
            return render.error("The user name you entered was not found in the system")

class add_glass:
    def GET(self):
        glasses = db.select('glasses', what='glass_name').list()
        clean_list = [item.glass_name for item in glasses]
        return clean_list

    def POST(self):
        i = web.input()
        if i.glass_name == "":
            return render.error("You must give the glass a name")
        try:
            db.insert('glasses', glass_name=i.glass_name)
        except sqlite3.IntegrityError, KeyError:
            return render.error(sys.exc_value)
        raise web.seeother('/user_home')

    def PUT(self):
        i = web.input()
        try:
            records_changed = db.update('glasses', where="id is %d" % int(i.id) , name=i.glass_name)
        except AttributeError:
            return render.error(sys.exc_value)
        return records_changed

    def DELETE(self):
        i = web.input()
        try:
            records_changed = db.delete('glasses', where="name is %s" % i.glass_name )
        except AttributeError:
            return render.error(sys.exc_value)
        return records_changed
class add_beer:
    def GET(self):
        i=web.input(order='style')
        records = db.query('select name,style,glass_name,overall,ibu,calories,abv from beer inner join glasses on beer.glass_id=glasses.id order by %s; ' % i.order ).list()
        return records

    def POST(self):
        i = web.input()
        if not session.logged_in:
            return render.error("You must be logged in to enter a beer")
        #check whether 1 day has passed since users last beer add.
        try:
            last_beer = db.select('users', what='last_beer', where="usr is \"%s\"" % session.usr).list()[0].last_beer
            glass_id = db.select('glasses', what='id', where="glass_name is \"%s\"" % i.glass, limit=1).list()[0].id
        except AttributeError:
            return render.error(sys.exc_value)

        today = datetime.date.today()
        if today == last_beer:
            return render.error("You must wait until tomorrow to add another beer")
        try:
            db.update('users', where="usr is \"%s\"" % session.usr, last_beer=today)
        except AttributeError:
            return render.error(sys.exc_value)
        try:
            number_added = db.insert('beer', ibu=int(i.ibu) , calories=int(i.calories), abv=str(i.abv), \
                                             style=i.style, location=i.location, glass_id=glass_id, name=i.name)
        except sqlite3.IntegrityError, KeyError:
            return render.error(sys.exc_value)
        except sqlite3.IntegrityError, ValueError:
            return render.error(sys.exc_value)
        raise web.seeother('/user_home')

    def PUT(self):
        i = web.input()
        try:
            glass_id = db.select('glasses', what='id', where="glass_name is \"%s\"" % i.glass, limit=1).list()[0].id
        except AttributeError:
            return render.error("Glass Name %s is not defined" % i.glass)
        try:
            records_changed = db.update('beer', where="id is %d" % int(i.id) , ibu=int(i.ibu), calories=int(i.calories), abv=str(i.abv), \
                                                style=i.style, location=i.location, glass_id=glass_id, name=i.name)
        except AttributeError:
            return render.error(sys.exc_value)
        return records_changed

    def DELETE(self):
        i.web.input()
        try:
            records_changed = db.delete('beer', where="id is %d" % int(i.id))
        except AttributeError:
            return render.error(sys.exc_value)
        return records_changed

class add_review:
    def GET(self):
        i = web.input(order='name',which='all')
        if(i.which == 'all'):
            try:
                reviews = db.query('select usr,email,name,style,aroma,appearance,taste,palate,bottle_style,overall from review inner join beer on review.beer=beer.id inner join users on users.id=review.reviewer order by %s;' % i.order).list()
                return reviews
            except AttributeError:
                return render.error("You can only sort on [usr,email,beer,style,aroma,appearance,taste,palate,bottle_style,overall]")
        else:
            try:
                beer_id_list = db.select('beer', what="id", where="name is \"%s\"" % i.which).list()
                if not beer_id_list:
                    return render.error("Your beer %s was not found in the Database" % i.which)
                else:
                    reviews = db.query('select usr,email,name,style,aroma,appearance,taste,palate,bottle_style,overall from review inner join beer on review.beer=beer.id inner join users on users.id=review.reviewer where beer.id=%d order by \"%s\";' % (int(beer_id_list[0].id), i.order)).list()
                    return reviews
            except AttributeError:
                return render.error("You can only sort on [usr,email,beer,style,aroma,appearance,taste,palate,bottle_style,overall]")
            return reviews

    def update_overall_beer_rating(self, web_params, isPut):
        # When this is called from a post, we can just update the average using the new data
        # When called from a put, we must extract the previous update then apply the new values
        if isPut: # Roll back the overall value. (Get the old review values, and extract them from the overall)
            previous_values = db.select('review', what="aroma,appearance,taste,palate, bottle_style",
                                                  where="id is %d" % int(web_params.review_id)).list()[0]
            old_review_total = (previous_values.aroma + previous_values.appearance + previous_values.taste +
                                previous_values.palate + previous_values.bottle_style)
            # Get previous overall and roll it back, reverting the last review.
            beer_overall_list = db.select ('beer', what="overall",
                                                   where="name is \"%s\"" % web_params.beer).list()
            if not beer_overall_list:
                return render.error("Your beer %s was not found in the list" % web_params.beer)
            else:
                current_overall = beer_overall_list[0].overall
                previous_overall = (current_overall * 2) - old_review_total
                # roll back the last review
                db.update('beer', where='name is "%s"' % web_params.beer, overall=previous_overall)
        # Then commence with the normal updating of the overall value
        new_review_total = ( int(web_params.aroma) + int(web_params.appearance) + int(web_params.taste) +
                             int(web_params.palate) + int(web_params.bottle_style) )
        beer_overall_list = db.select ('beer', what="overall",
                                    where="name is \"%s\"" % web_params.beer).list()
        # Make sure we selected a valid beer
        if not beer_overall_list:
            return render.error("Your beer %s was not found in the list" % web_params.beer)
        new_overall = (float(beer_overall_list[0].overall) + float(new_review_total))/2
        db.update('beer', where='name is "%s"' % web_params.beer, overall=new_overall)

    def userCanReviewThisBeer(self, web_params):
        # Get the users user_id
        reviewer = db.select('users', what="id", where="usr is \"%s\"" % session.usr).list()[0].id
        # Get the id of the beer under review
        beer_id_list = db.select ('beer', what="id", where="name is \"%s\"" % web_params.beer).list()
        if not beer_id_list:
            return render.error("Your beer %s was not found in the list" % web_params.beer)
        else:
            beer_id = beer_id_list[0].id
        # Get date of last review (if it exists)
        date_of_last_review = db.select('week_review', what="review_date", where="user_id is %d and beer_id is %d" % (reviewer, beer_id)).list()
        if not date_of_last_review:
            # Update the table with today as the last review
            db.insert('week_review', user_id=reviewer, beer_id=beer_id, review_date=datetime.date.today())
            #no previous review
            return True
        # ensure that last review was more than 1 week ago.
        today = datetime.date.today()
        last_review_date_parts = date_of_last_review[0].review_date.split('-')
        last_review_date_object = datetime.date(int(last_review_date_parts[0]), int(last_review_date_parts[1]), int(last_review_date_parts[2]))
        seven_days = datetime.timedelta(days=7)
        if today > last_review_date_object + seven_days:
            return True
        return False

    def POST(self):
        i = web.input()
        if session.logged_in:
            if not self.userCanReviewThisBeer(i):
                return render.error("You must wait at least a week to review this beer again")
            try:
                beer_id_list = db.select('beer', what="id", where="name is \"%s\"" % i.beer).list()
                if not beer_id_list:
                    return render.error("Beer %s not found in list" % i.beer)
                beer_id = beer_id_list[0].id
                reviewer = db.select('users', what="id", where="usr is \"%s\"" % session.usr).list()[0].id
                reviews_added = db.insert('review', aroma=i.aroma, appearance=i.appearance,
                                                    taste=i.taste, palate=i.palate, bottle_style=i.bottle_style,
                                                    beer=beer_id, reviewer=reviewer)
                self.update_overall_beer_rating(i, False)
            except sqlite3.IntegrityError, KeyError:
                return render.error(sys.exc_value)
            except IndexError:
                return render.error("Beer %s not found in the list" % i.beer)
            except AttributeError:
                return render.error(sys.exc_value)
            raise web.seeother('/')
        raise web.error("You must have a logged_in cookie to add a Review")

    def PUT(self):
        i = web.input()
        if session.logged_in:
            # Make sure we were giveen a valid review_id
            if not db.select('review', what="id", where="id is %d" % int(i.review_id)).list():
                return render.error("The review id %d is invald" % int(i.review_id))
            try:
                # Update overall rating must be called before the database is updated
                # since the current rating numbers will be used to roll back the overall beer rating.
                self.update_overall_beer_rating(i, True)
                beer_id_list = db.select('beer', what="id", where="name is \"%s\"" % i.beer).list()
                if not beer_id_list:
                    return render.error("Beer %s not found in list" % i.beer)
                beer_id = beer_id_list[0].id
                reviewer = db.select('users', what="id", where="usr is " + "\"%s\"" % session.usr).list()[0].id
                reviews_added = db.update('review', where='id is %d' % int(i.review_id), aroma=i.aroma, appearance=i.appearance, taste=i.taste, palate=i.palate, \
                                                    bottle_style=i.bottle_style, beer=beer_id, reviewer=reviewer)
            except sqlite3.IntegrityError, KeyError:
                return render.error(sys.exc_value)
            except AttributeError:
                return render.error(sys.exc_value)
            except ValueError:
                return render.error("Did you pass a beer name or a beer_id? Only accepts beer_id")
            raise web.seeother('/') #this is the success exit point.
        raise web.error("You must have a logged_in cookie to add a Review")

    def DELETE(self):
        i = web.input()
        if session.logged_in:
            try:
                reviewer = db.select('users', what="id", where="usr is " + "\"%s\"" % session.usr).list()[0].id
                who_reviewed = db.select('review', what="reviewer", where='id is %d' % int(i.review_id)).list()[0].id
                if reviewer == who_reviewed:
                    db.delete('review', where='id is %d' % int(i.review_id))
                else:
                    web.error("You may only delete your own reviews")
            except AttributeError:
                return render.error(sys.exc_value)
        else:
            raise web.error("You must be logged in to do that")
        return False

class fav:
    def GET(self):
        i = web.input(order='name',user='all')
        print i
        if i.user == 'all':
            try:
                all_favs = db.query("select usr,name from beer inner join favorites on favorites.beer_id = beer.id inner join users on users.id=favorites.user_id order by %s" % i.order).list()
                print all_favs
                return all_favs
            except sqlite3.OperationalError:
                return render.error("something went wrong getting the favorites list")
        else:
            # find the user Id in the database, then print only the favorites that go with that user_id
            try:
                user_id = db.query("select id from users where usr is \"%s\"" % i.user).list()[0].id
            except sqlite3.OperationalError:
                return render.error("DB error, maybe the username requsted does not exsit")
            try:
                user_favs = db.query("select name from beer inner join favorites on favorites.beer_id = beer.id where user_id=%d" % user_id).list()
                return user_favs
            except sqlite3.OperationalError:
                return render.error("DB error, maybe the username requsted does not exsit")
    def POST(self):
        i = web.input()
        if session.logged_in:
            try:
                user_id = db.select('users', what="id", where="usr is \"%s\"" % session.usr).list()[0].id
                beer_id = db.select('beer', what="id", where="name is \"%s\"" %  i.beer).list()[0].id
                n = db.insert('favorites', user_id=user_id, beer_id=beer_id)
            except sqlite3.IntegrityError, KeyError:
                return render.error(sys.exc_value)
            raise web.seeother('/user_home')
        else:
            return render.error("Please log in to add to your favorites")
    #NO PUT, nothing to update, if you have a fav you don't want use the DELETE method
    def DELETE(self):
        #allow deletion based on logged in status and a beer name.
        i = web.input()
        if session.logged_in:
            try:
                user_id = db.select('users', what="id", where="usr is \"%s\"" % session.usr).list()[0].id
                beer_id = db.select('beer', what="id", where="name is \"%s\"" %  i.beer).list()[0].id
                n = db.delete('favorites', where="beer_id=%d and user_id=%d" % (beer_id, user_id))
            except sqlite3.IntegrityError, KeyError:
                return render.error(sys.exc_value)
            raise web.seeother('/user_home')
        else:
            return render.error("Please log in to edit to your favorites")

if __name__ == "__main__":
    app.run()
