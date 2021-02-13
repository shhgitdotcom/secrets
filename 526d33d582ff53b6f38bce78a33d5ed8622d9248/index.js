const express = require('express')
const compression = require('compression')
const app = express()
const server = require('http').createServer(app)
const io = require('socket.io')(server)
const ejs = require('ejs')
const path = require('path')
const bodyParser = require("body-parser")
const urlencodedParser = bodyParser.urlencoded({extended: false});

app.use(compression())

app.use('/styles',express.static(__dirname + '/static/styles'))
app.use('/img',express.static(__dirname + '/static/styles/img'))
app.use('/js',express.static(__dirname + '/static/js'))

app.engine('html', ejs.renderFile)
app.set('view engine', 'html')
app.set('views', __dirname)

url = 'mongodb+srv://Kxxxxo:ua3xxxe@cluster0-8humy.gcp.mongodb.net/Duties'
db = require('monk')(url)
collection = db.get('Duties')

function sort(a,b){
	a = a.split('.')
	b = b.split('.')
	if (a[2] != b[2]) 
		return a[2] - b[2]
	if (a[1] != b[1]) 
		return a[1] - b[1]
	else 
		return a[0] - b[0]
}

app.get('/', async function(request, response){
	database = await collection.find({}, {projection: {_id: 0}})
	response.render(__dirname + "/static/HTML/duties_old.html", {database: database})
	// response.render(__dirname + "/static/HTML/duties_old.html")
})

app.get('/new', async function(request, response){
	// database = await collection.find({}, { projection: { _id: 0}})
	// response.render(__dirname + "/public/HTML/duties.html", {database: database})
	response.render(__dirname + "/static/HTML/duties.html")
})

async function getDB(){
	return await collection.find({}, {projection: {_id: 0}})
}

app.post("/add", urlencodedParser, add)

app.post("/mobile/add", urlencodedParser, add)

app.post("/remove", urlencodedParser, remove)

app.post("/mobile/remove", urlencodedParser, remove)

io.on('connection', async function(socket){
	console.log(`Подключился: ${socket.id}`)

	socket.on('get db request', async function(){
		socket.emit('get db response', {db: await getDB()})
	})

	socket.on('add request', async function(data){
		if (data.date){
			if (data.student1 || data.student2){

				database = await collection.find({}, {projection: {_id: 0}})

				let currentStudent1, currentStudent2
				for (let student of database){
					if (student.name == data.student1)
						currentStudent1 = student
					else if (student.name == data.student2)
						currentStudent2 = student
				}

				if (currentStudent1 || currentStudent2){
					let date = data.date.split('-').reverse().join('.')
				    if (currentStudent1)
						await collection.update({name: currentStudent1.name}, {$set: {dates: currentStudent1.dates.concat(date).sort(sort)}})
					if (currentStudent2)
						await collection.update({name: currentStudent2.name}, {$set: {dates: currentStudent2.dates.concat(date).sort(sort)}})

					socket.emit('add response', {success: true, title: 'Успешно добавлено', text: ''})
					io.emit('update db', {db: await collection.find({}, {projection: { _id: 0}})})
				}
				else {
					socket.emit('add response', {success: false, title: 'Не удалось добавить', text: 'Студент не найден'})
				}
			}
			else if (!data.currentStudent1 && !data.currentStudent2){
				socket.emit('add response', {success: false, title: 'Не удалось добавить', text: 'Ни один студент не выбран'})
			}
		}
		else {
			socket.emit('add response', {success: false, title: 'Не удалось добавить', text: 'Не указана дата'})
		}
	})

	socket.on('remove request', async function(data){
		if (data.student && data.date){

			database = await collection.find({}, {projection: {_id: 0}})

			let currentStudent
			for (let student of database){
				if (student.name == data.student)
					currentStudent = student
			}

			if (currentStudent && currentStudent.dates.includes(data.date)){
				currentStudent.dates.splice(currentStudent.dates.indexOf(data.date), 1)
				await collection.update({name: currentStudent.name}, {$set: {dates: currentStudent.dates}})

				socket.emit('remove response', {success: true, title: 'Успешно удалено', text: ''})
				io.emit('update db', {db: await collection.find({}, {projection: { _id: 0}})})
			}
			else {
				socket.emit('remove response', {success: false, title: 'Не удалось удалить', text: 'Студент или дата не найдены'})
			}
		}
		else if (!data.student){
			socket.emit('remove response', {success: false, title: 'Не удалось удалить', text: 'Не выбран студент'})
		}
		else if (!data.date){
			socket.emit('remove response', {success: false, title: 'Не удалось удалить', text: 'Не выбрана дата'})
		}
	})

	socket.on('disconnect', function(){
		console.log(`Отключился: ${socket.id}`)
	})
})

async function add(request, response) {
	database = await collection.find({}, { projection: { _id: 0}})
	var student1, student2
	for (i of database){
		if (i.name == request.body.studentName1)
			student1 = i
		else if (i.name == request.body.studentName2)
			student2 = i
	}
	if (student1 || student2){
		let selectedDate = request.body.date.split('-').reverse().join('.')
	    if (student1)
			await collection.update({name: student1.name}, {$set: {dates: student1.dates.concat(selectedDate).sort(sort)}})
		if (student2) 
			await collection.update({name: student2.name}, {$set: {dates: student2.dates.concat(selectedDate).sort(sort)}})
		response.render(__dirname + '/static/HTML/result.html', {text: 'Успешно добавлено'})
	}
	else
		response.render(__dirname + '/static/HTML/result.html', {text: 'Не добавлено'});
}

async function remove(request, response) {
	database = await collection.find({}, { projection: { _id: 0}})
	var student
	for (i of database){
		if (i.name == request.body.studentName)
			student = i
	}
	if (student && student.dates.indexOf(request.body.date) != -1) {
		student.dates.splice(student.dates.indexOf(request.body.date), 1)
		await collection.update({name: student.name}, {$set: {dates: student.dates}})
		response.render(__dirname + '/static/HTML/result.html', {text: 'Успешно удалено'});
	}
	else 
		response.render(__dirname + '/static/HTML/result.html', {text: 'Не удалось удалить'});
}

const PORT = process.env.PORT || 3000
server.listen(PORT, function (){
	console.log(`Server started on port: ${PORT}`)
})
