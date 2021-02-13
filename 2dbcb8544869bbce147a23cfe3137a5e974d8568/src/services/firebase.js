import firebase from 'firebase/app'
import 'firebase/database'

const firebaseConfig = {
    apiKey: 'AIzaSyASlp4cZJVb5_WdhrE6PJKgUy_ghYNjo2B',
    authDomain: 'pokemon-game-2c608.firebaseapp.com',
    databaseURL: 'https://pokemon-game-2c608-default-rtdb.europe-west1.firebasedatabase.app',
    projectId: 'pokemon-game-2c608',
    storageBucket: 'pokemon-game-2c608.appspot.com',
    messagingSenderId: '564953470707',
    appId: '1:564953470707:web:853aec4a99b5523a62d7bc',
}
firebase.initializeApp(firebaseConfig)

class FirebaseService {
    constructor() {
        this.fire = firebase
        this.database = this.fire.database()
    }

    getPokemonsSocket = (cb) => {
        this.database.ref('pokemons').on('value', (snapshot) => cb(snapshot.val()))
    }

    offPokemonsSocket = () => {
        this.database.ref('pokemons').off()
    }

    getPokemonsOnceAsync = async () => {
        return await this.database
            .ref('pokemons')
            .once('value')
            .then((snapshot) => snapshot.val())
    }

    updatePokemon = (key, poke) => {
        this.database.ref(`pokemons/${key}`).set(poke)
    }

    addPokemon = (poke, cb) => {
        const newPostKey = this.database.ref().child('pokemons').push().key
        this.database
            .ref(`pokemons/${newPostKey}`)
            .set(poke)
            .then(() => {
                cb && cb()
            })
    }
}

export default FirebaseService
