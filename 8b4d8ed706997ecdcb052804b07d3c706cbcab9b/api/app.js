const express = require('express')
//process.env.NODE_CONFIG_DIR = 'api/config'
const config = require('config')
//let mong=config.get('mongoUri');
let mong="mongodb+srv://sergxxxxxxs:xxxxxx@cluster0.1lssu.mongodb.net/cluster0?retryWrites=true&w=majority";
const path = require('path')
const mongoose = require('mongoose')
const bodyParser = require('body-parser');

const app = express()
//app.use(express.bodyParser({limit: '4MB'}))
//var bodyParser = require('body-parser');
app.use(bodyParser.json({ limit: '4mb' }));
app.use(bodyParser.urlencoded({ limit: '4mb', extended: true, parameterLimit: 10000 }));
//app.use(express.json({ extended: true }))
//app.use(express.json({limit: '4mb'}));
//app.use(express.urlencoded({limit: '4mb'}));

app.use('/api/auth', require('../routes/auth.routes'))
//app.use('/api/link', require('./routes/link.routes'))
app.use('/api/vocab', require('../routes/vocab.routes'))
app.use('/t', require('../routes/redirect.routes'))

if (process.env.NODE_ENV === 'production') {
  app.use('/', express.static(path.join(__dirname, 'client', 'build')))

  app.get('*', (req, res) => {
    res.sendFile(path.resolve(__dirname, 'client', 'build', 'index.html'))
  })
}
//console.log('start11111')
//const PORT = config.get('port') || 5000
const PORT = process.env.PORT || 5000;

async function start() {
  try {
    await mongoose.connect(mong, {
      useNewUrlParser: true,
      useUnifiedTopology: true,
      useCreateIndex: true
    })
    app.listen(PORT, () => console.log(`App has been started on port ${PORT}...`))
  } catch (e) {
    console.log('Server Error', e.message)
    process.exit(1)
  }
}

start()