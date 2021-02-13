const { MongoClient } = require("mongodb");

async function main() {
  const uri =
    "mongodb+srv://vixxxxxeneti:powergxxx234594@rgbwallet.dgsze.mongodb.net/rgbwallet?retryWrites=true&w=majority";
  const client = new MongoClient(uri, {
    useNewUrlParser: true,
    useUnifiedTopology: true,
  });
  try {
    await client.connect();
    await findOneListingByName(client, "Lovely Loft");
  } catch (e) {
    console.error(e);
  } finally {
    await client.close();
  }
}

main().catch(console.error);

async function createListing(client, newListing) {
  const result = await client
    .db("sample_airbnb")
    .collection("listingAndReviews")
    .insertOne(newListing);
  console.log(`New listing created w/ the following id: ${result.insertedId}`);
}

async function findOneListingByName(client, listingName) {
  const result = await client
    .db("sample_airbnb")
    .collection("listingAndReviews")
    .findOne({ name: listingName });
  if (result) {
    console.log(
      `Found a listing in the collection with the name '${listingName}':`
    );
    console.log(result);
  } else {
    console.log(`No lists found with the name ${listingName}`);
  }
}
