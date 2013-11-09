# NewAuth

NewAuth is a barebones Ruby on Rails web application with user authentication built in.  It uses Devise to provide authentication, and a SqlLite3 database to store the users.  It incorporates several features:

* There is a landing (home) page for all visitors initially.  Once logged in as a user, each user has their own dashboard, and during their session this becomes their home page.  

## Dependencies

Before creating the application, you will need:

* The Ruby language (version 1.9.3)
* Rails 3.2

## Installation

First, clone the GitHub repo:

```
$ git clone https://github.com/lanebuckingham/newauth-sql.git
```

Then install the gems:

```
$ bundle install
```

Then you will want to change the application name from NewAuth to a new name.  There is a handy shell script provided which will perform all the tedious find-and-replace for you.  

First, from the root of the app directory, run the following to ensure the script is executable:

```
$ chmod +x change_name.sh
```

Then run the script:

```
$ ./change_name.sh
```

After that is done, run the following to re-create your database:

```
$ rake db:migrate VERSION=0
$ rake db:migrate
```

Then run the following to create your initial users, including the admin user:

```
$ rake db:seed
```

Finally, test the application:

```
$ rails server
```

## Administration

NewAuth uses [RailsAdmin](https://github.com/sferik/rails_admin) to manage the website.  To access it, navigate to /admin and you will be prompted for an admin login.  Admin users cannot be created online for security purposes.  They must be created via command-line.  See the db/seeds.rb file for the initial admin login (assuming you ran ```$ rake db:seed``` above).


## Information

#### Devise

NewAuth relies heavily on the Devise gem to perform user authentication.  For more information, see the [documentation](http://devise.plataformatec.com.br/) for Devise or the [GitHub repo](https://github.com/plataformatec/devise).
