import React, { useEffect, useState } from 'react'
import { View, StyleSheet } from 'react-native'
import {
  GoogleSignin,
  statusCodes,
} from '@react-native-community/google-signin'
import { GoogleButton } from '../../components/auth'
import { useAuth } from '../../context/AuthContext'

const GoogleSignIn = () => {
  useEffect(() => {
    GoogleSignin.configure({
      webClientId:
        '473036889000-niatdco3v3bucf112gsfg2qle2dfhca1.apps.googleusercontent.com',
      offlineAccess: true,
      forceCodeForRefreshToken: true,
    })
  }, [])

  const { signInGoogle } = useAuth()
  const [loading, setLoading] = useState(false)

  const handleGoogleSignIn = async () => {
    try {
      setLoading(true)
      await GoogleSignin.hasPlayServices()
      const userInfo = await GoogleSignin.signIn()
      await signInGoogle(userInfo.idToken)
    } catch (error) {
      setLoading(false)
      if (error.code === statusCodes.SIGN_IN_CANCELLED) {
        // user cancelled the login flow
      } else if (error.code === statusCodes.IN_PROGRESS) {
        // operation (e.g. sign in) is in progress already
      } else if (error.code === statusCodes.PLAY_SERVICES_NOT_AVAILABLE) {
        // play services not available or outdated
      } else {
        console.error(error)
      }
    }
  }

  return (
    <View style={styles.googleButton}>
      <GoogleButton signIn={handleGoogleSignIn} disabled={loading} />
    </View>
  )
}

const styles = StyleSheet.create({
  googleButton: {
    marginHorizontal: 50,
  },
})

export default GoogleSignIn
