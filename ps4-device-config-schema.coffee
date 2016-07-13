module.exports = {
  title: "pimatic-ps4waker device config schemas"
  Ps4PowerSwitch: {
    title: "PS4 power switch"
    type: "object"
    properties:
      credentialsPath:
        description: "Path to credentials file"
        type: "string"
      ipAddress:
        description: "PS4 console IP address"
        type: "string"
        required: false
  }
}