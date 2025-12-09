const mongoose = require("mongoose");

const userSchema = new mongoose.Schema({
  address: { 
    type: String, 
    required: true, 
    unique: true, 
    lowercase: true 
  },
  totalSwaps: { 
    type: Number, 
    default: 0 
  },
  totalReferred: { 
    type: Number, 
    default: 0 
  },
  referralRewardsEarned: { 
    type: String, 
    default: "0" 
  },
});

module.exports = mongoose.model("User", userSchema);
