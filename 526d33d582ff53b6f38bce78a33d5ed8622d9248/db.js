// const mongoose = require('mongoose')
// 
// 
// mongoose.connect('mongodb+srv://Kicxxxxo:uaxxxkqwe@cluster0-8humy.gcp.mongodb.net/moobot', {
// 	useNewUrlParser: true,
// 	useFindAndModify: false
// }, function(error){
// 	if (error) throw error
// 		
// 	console.log('Connected')
// })
// 
// console.log(mongoose.find({}))
// 
// mongoose.disconnect()

const MongoClient = require("mongodb").MongoClient;

const url = "\x6D\x6F\x6E\x67\x6F\x64\x62\x2B\x73\x72\x76\x3A\x2F\x2F\x4B\x69\x63\x73\x68\x69\x6B\x78\x6F\x3A\x75\x61\x33\x77\x69\x6B\x71\x77\x65\x40\x63\x6C\x75\x73\x74\x65\x72\x30\x2D\x38\x68\x75\x6D\x79\x2E\x67\x63\x70\x2E\x6D\x6F\x6E\x67\x6F\x64\x62\x2E\x6E\x65\x74\x2F\x6D\x6F\x6F\x62\x6F\x74"
const mongoClient = new MongoClient(url, { useNewUrlParser: true, useUnifiedTopology: true });

mongoClient.connect(async function(err, client){
      
    const db = client.db("Duties");
    const collection = db.collection("Duties");
	
	array = await new Promise(function(resolve, reject){
		collection.find({}, { projection: { _id: 0}}).toArray(function(error, result){
			resolve(result)
		})
	})
	
	module.exports = {
		array: new Promise(function(resolve, reject){
		collection.find({}, { projection: { _id: 0}}).toArray(function(error, result){
				resolve(result)
			})
		})
	}
	
	console.log(array)
	
// 	collection.find({}, { projection: { _id: 0}}).toArray(function(error, result){
// 		console.log(result)
// 	})
	
// 	collection.find({}, { projection: { _id: 0}}).toArray(function(error, result){
// 				console.log(result)
// 				let data = result
// 			})
// 	
	
// 	collection.updateOne({
// 		'axle0sp'
// 	},{
// 		$set: {gold: 0, inventory: inventory}
// 	}, function(error, result){
// 		if (error) throw error
// 		console.log('Updated')
// 	})
// 	
// 	client.close();
});
