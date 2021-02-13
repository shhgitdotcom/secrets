# Customer Service

This is a Spring Boot application that's used with the "Building a CRM Application " series on the <a href="https://careydevelopment.us" target="_blank">Carey Development website</a>.

It's a microservice that handles requests related to customers (including contacts and accoutns) within an ecosystem.

Each branch within this repo is related to a distinct guide. The master branch holds the latest version of the application.

If you want to follow along with the series, just visit the URL that points to the <a href="https://careydevelopment.us/tag/careydevelopmentcrm" target="_blank">careydevelopmentcrm tag</a>. 

Remember, all guides are in reverse chronological order so if you want to start from the beginning, you'll need to go to the last page.

## You Need to Make Updates
Bad news: you can't just clone this source and run it right out of the box. You'll need to make some changes.

For example, you'll need to update `application.properties`. Specifically, look at these two properties:
- `ecosystem.properties.file.location=/etc/careydevelopment/ecosystem.properties`
- `customer.properties.file.location=/etc/careydevelopment/customer.properties`

## Configuration
Although some of the configuration options are located in `application.properties`, not all of them are there.

Some info, like the JWT secret and the MongoDB connection string, are located in a separate properties file stored outside of the source repo. That's so I don't accidentally check in secure info.

The locations of the external properties files are specified in the `application.properties` file. Look for the `ecosystem.properties.file.location` and the `product.properties.file.location` properties.

Here's a list of the properties in that `ecosystem.properties` file:
* `jwt.secret` - the secret used to sign JWTs
* `mongodb.carey-ecosystem.connection` - the connection string to get to the MongoDB (in the format: mongodb://name:password@server:port)
* `ecosystem-user-service.endpoint` - the base URL to <a href="https://github.com/careydevelopment/ecosystem-user-service">the user service</a>
* `customer-service.endpoint` - the base URL to <a href="https://github.com/careydevelopment/ecosystem-customer-service">the customer service.</a>
* `geo-service.endpoint` - the base URL to state and country lookups (currently private repo).
* `product-service.endpoint` - the base URL to <a href="https://github.com/careydevelopment/ecosystem-product-service">the product service.</a>
* `crm-service.endpoint` - the base URL to <a href="https://github.com/careydevelopment/crm-service">the CRM service.</a> 

The `customer.properties` file simply contains a URL to the MongoDB:
* `mongodb.carey-customer.connection=mongodb://user:password@mycoolhost.com:1100`

## Dependencies

This service uses <a href="https://github.com/careydevelopment/ecosystem-user-service">ecoystem-user-service</a> to get user information. You'll
need to deploy that service if you want to persist customer-related details. 

## The UI
The Carey Development CRM <a href="https://github.com/careydevelopment/careydevelopmentcrm">source</a> uses this service.


