pragma circom 2.0.4;

include "../node_modules/circomlib/circuits/poseidon.circom";
include "./logicgates.circom";
include "../node_modules/circomlib/circuits/gates.circom";
include "./playerBalls.circom";
include "./playingCards.circom";
include "../node_modules/circomlib/circuits/mux4.circom";
include "../node_modules/circomlib/circuits/mux1.circom";
include "../node_modules/circomlib/circuits/mux2.circom";


function getPlayerStertPos(playerid){
    if (playerid == 0){
        return 0;
    }
    else if (playerid == 1){
        return 19;
    }
    else if (playerid == 2){
        return 37;
    }
    else if (playerid == 3){
        return 55;
    }
    return 0;
}

template jakaroo(){
    signal input playerId; // To identify which player (No player can jumb above its own ball)
    signal input playground[16]; // one array for the player's balls
    signal input players_cards[5];
    signal input player_card;
    signal input played_ball;
    signal input options[1]; // Optional, depending on played card (1, 11) [burn]
    // signal input current_playground_commit; // hash of playground
    // signal input players_cards_commit;
    signal output new_playground_out[16];
    signal output new_cards_commit[5];

    signal burn <== options[0];
    assert( ((1-burn) * burn) == 0); // Make sure burn is either 0 or 1

    // Assert input cards is between 0 & 13
    for(var i=0; i<5; i++){
        assert(players_cards[i] >= 0 && players_cards[i] <= 13);
    }

    // Assert burnign non-burnale King
    if(burn && players_cards[player_card] == 13){
        for(var i=playerId*4; i<playerId*4+4; i++){
            assert(playground[i] != 100);
        }
    }
    
    // Assert burning non-burnable Normal
    if(burn && players_cards[player_card] != 13){
        for(var i=playerId*4; i<playerId*4+4; i++){
            assert(playground[i] == 100 || playground[i] == 200); // 200 is the winning area
        }
    }



    // Normal signal
    signal new_playground[16];
    signal new_players_cards[5];
    signal back_playground[16];
    signal winning_playground[16];

    // signal output new_playground_commit; // might not be needed

    // Extract the card and make sure it is not an empty card slot
        // check its value if it is value between 0,4 - then check the array index value not 0.
        // ???????????????????????????????
        component rangeCard = RangeProof(16);
        rangeCard.in <-- player_card;
        rangeCard.range[0] <== 0;
        rangeCard.range[1] <== 4;
        rangeCard.out === 1;

        // Make sure player plays his own ball
        component only_player_balls = onlyPlayerBalls();
        only_player_balls.playerId <== playerId;
        only_player_balls.played_ball <== played_ball;
        only_player_balls.output0 === 1; 
        
        // Determine card functionality     
        // Cards 1-1, 1-11, 2, 3, 4-b, 6, 7, 8, 9, 10, 12

        // Mux4 will be responsable for choosen cards.
        component selector = playingCards();
        selector.player_card <== player_card;
        for (var i=0; i<5; i++){
            selector.players_cards[i] <== players_cards[i];
        }
        component mux4 = Mux4();
        
        for (var i=0; i<16; i++){
            mux4.c[i] <== i;
            
        }

        for (var i=0; i<4; i++){
            mux4.s[i] <== selector.binary_selector[i];
        }
        
        /* 
        1 -> 1 step forward
        2 -> 2 steps forward
        3 -> 2 steps forward
        4 -> 4 steps backward
        5 -> 5 steps forward
        6 -> 6 steps forward
        7 -> 7 steps forward
        8 -> 8 steps forward
        9 -> 9 steps forward
        10 -> 10 steps forward
        11 -> 11 steps forward
        12 -> Queen -12- steps forward
        13 -> 13 King place
        14 -> J Jack 11 steps backward
        */    

    // Balls Placement:
        // Starting Locations: 
        // Player 1: 0
        // Player 2: 19
        // Player 3: 37
        // Player 4: 55

        component IsEqual_P1[4];
        component IsEqual_P2[4];
        component IsEqual_P3[4];
        component IsEqual_P4[4];

        var a = 4;
        var b = 8;
        var c = 12;

        for (var i=0; i<4; i++){
            IsEqual_P1[i] = IsEqual();
            IsEqual_P1[i].in[0] <== playground[i];
            IsEqual_P1[i].in[1] <== 100;
            (IsEqual_P1[i].out) ==> back_playground[i];
            
            IsEqual_P2[i] = IsEqual();
            IsEqual_P2[i].in[0] <== playground[a];
            IsEqual_P2[i].in[1] <== 100;
            (IsEqual_P2[i].out)*(19+1) ==> back_playground[a];
            a = a+1;

            IsEqual_P3[i] = IsEqual();
            IsEqual_P3[i].in[0] <== playground[b];
            IsEqual_P3[i].in[1] <== 100;
            (IsEqual_P3[i].out)*(37+1) ==> back_playground[b];
            b=b+1;

            IsEqual_P4[i] = IsEqual();
            IsEqual_P4[i].in[0] <== playground[c];
            IsEqual_P4[i].in[1] <== 100;
            (IsEqual_P4[i].out)*(55+1) ==> back_playground[c];
            c = c+1;
        }
        // for printing:
        for (var i=0; i<16; i++){
            // log(playground[i]);
            // log(back_playground[i]);
        }
    
        component isThePlayedBall[16];
        component mux2[16];
        component cardIsKing[16];
        component isBallInHive[16];
        component And[16];
        component Isnotzero[16];
        component And2[16];
        component playedBallAndnotBurn[16];
        
        for(var i = 0; i < 16; i++){
            mux2[i] = Mux2();
            isThePlayedBall[i] = IsEqual();
            cardIsKing[i] = IsEqual();
            Isnotzero[i] = IsNotZero();
            And[i] = and();
            isBallInHive[i] = GreaterThan(18);
            And2[i] = and();
        }
        // four options for this: 
        // 1. & 2. are negalgable.
        // 3. doing the chaings in playground.
        // 4. the card is king & playble ball is in base playground.
        var changing_pos;
        for (var i = 0; i < 16; i++){

            // make sure this is the played ball that we are using.
            isThePlayedBall[i].in[0] <== played_ball; 
            isThePlayedBall[i].in[1] <== i;           
            // check if this a King card or not.
            cardIsKing[i].in[0] <== 13;          
            cardIsKing[i].in[1] <== mux4.out;

            isBallInHive[i].in[0] <== back_playground[i]; 
            isBallInHive[i].in[1] <== 0;
            //                                  
            
            assert((!isThePlayedBall[i].out) || 
                   ( isBallInHive[i].out &&  cardIsKing[i].out) || 
                   (!isBallInHive[i].out && !cardIsKing[i].out) || 
                   burn); // Don't move any non-played ball.
            /*
                isBallInHive | cardIsKing | R
                0|0 F
                0|1 F
                1|0 -> T
                1|1 F
            */
            //       index@played ball     Ball out of base        The played card is King
            // assert(!(isThePlayedBall[i].out   && (!isBallInHive[i].out && cardIsKing[i].out))      || burn); // King Dosen't move any playable ball.
            // assert((!isThePlayedBall[i].out)   || (!isBallInHive[i].out && cardIsKing[i].out)      || burn); // King Dosen't move any playable ball.
            //0 
            //1
            //-2
            //3
            //4
            
            for (var j=0;j<16;j++){
                // log(playground[j]);
                // log(isThePlayedBall[i].out);
                // assert(!(getPlayerStertPos(playerId) != playground[j] && isThePlayedBall[i].out && (isBallInHive[k].out && cardIsKing[i].out)));  // Make sure that no other balls in start position when played new ball
            }

            // And[i].a <== Isnotzero[i].out;
            And[i].a <== isBallInHive[i].out;
            And[i].b <== cardIsKing[i].out;
            
            And2[i].a <== And[i].out;
            And2[i].b <== isThePlayedBall[i].out;
            
            playedBallAndnotBurn[i] = and();
            playedBallAndnotBurn[i].a <== isThePlayedBall[i].out;
            playedBallAndnotBurn[i].b <== 1-burn; // Not burn

            mux2[i].c[0] <== playground[i];                // s[1] = 0, s[0] = 0
            mux2[i].c[1] <== playground[i];                // s[1] = 0, s[0] = 1 
            mux2[i].c[2] <-- (playground[i]+ mux4.out)%74; // s[1] = 1, s[0] = 0
            mux2[i].c[3] <== back_playground[i]-1;           // s[1] = 1, s[0] = 1
            
            mux2[i].s[1] <== playedBallAndnotBurn[i].out;
            mux2[i].s[0] <== And2[i].out; 

            mux2[i].out ==> new_playground[i];
        }

// Check winning

    // winning balls => 200, 300, 400, 500. 
        component winRange_P1[4];
        component winRange_P2[4];
        component winRange_P3[4];
        component winRange_P4[4];

        component mux_P1[4];
        component mux_P2[4];
        component mux_P3[4];
        component mux_P4[4];

        var j = 4;
        var k = 8;
        var u = 12;
        for (var i=0; i<4; i++){
            mux_P1[i] = Mux1();
            mux_P2[i] = Mux1();
            mux_P3[i] = Mux1();
            mux_P4[i] = Mux1();

            winRange_P1[i] = RangeProof(16);
            winRange_P1[i].in <== new_playground[i];
            winRange_P1[i].range[0] <== 72;
            winRange_P1[i].range[1] <== 73;
            winRange_P1[i].out ==> winning_playground[i];

            mux_P1[i].c[0] <== new_playground[i];
            mux_P1[i].c[1] <== 200;
            mux_P1[i].s    <== winRange_P1[i].out;
            mux_P1[i].out  ==> new_playground_out[i];

            winRange_P2[i] = RangeProof(16);
            winRange_P2[i].in <== new_playground[j];
            winRange_P2[i].range[0] <== 17;
            winRange_P2[i].range[1] <== 18;
            winRange_P2[i].out ==> winning_playground[j];

            mux_P2[i].c[0] <== new_playground[j];
            mux_P2[i].c[1] <== 300;
            mux_P2[i].s    <== winRange_P2[i].out;
            mux_P2[i].out  ==> new_playground_out[j];
            j = j+1;

            winRange_P3[i] = RangeProof(16);
            winRange_P3[i].in <== new_playground[k];
            winRange_P3[i].range[0] <== 35;
            winRange_P3[i].range[1] <== 36;
            winRange_P3[i].out ==> winning_playground[k];

            mux_P3[i].c[0] <== new_playground[k];
            mux_P3[i].c[1] <== 400;
            mux_P3[i].s    <== winRange_P3[i].out;
            mux_P3[i].out  ==> new_playground_out[k];
            k=k+1;

            winRange_P4[i] = RangeProof(16);
            winRange_P4[i].in <== new_playground[u];
            winRange_P4[i].range[0] <== 53;
            winRange_P4[i].range[1] <== 54;
            winRange_P4[i].out ==> winning_playground[u];
            
            
            mux_P4[i].c[0] <== new_playground[u];
            mux_P4[i].c[1] <== 500;
            mux_P4[i].s    <== winRange_P4[i].out;
            mux_P4[i].out  ==> new_playground_out[u];
            u = u+1;
            
    }

    // mux for king

    component mux_2[16];

    signal new_cards[5];
    component deletePlayedCard = DeletePlayedCard();
    deletePlayedCard.played_card <== player_card;
    for(var i=0; i<5; i++){
        deletePlayedCard.old_cards[i] <== players_cards[i];
    }

    for(var i=0; i<5; i++){
        new_cards_commit[i] <== deletePlayedCard.new_cards[i];
    }
    
    for (var i=0; i<16; i++){
        // log(new_playground[i]);
    }
}


component main = jakaroo();

// circom tester => read circom to feed inputs. 
// Card function => King
// Card shuffling => smart contract
// Generate Solidity & Wasm + power of tau, proof, .... etc.. . 
// connecting of four wallets. 
// Deployment on test net. 
// writing readme + record a video. 
// checking if the ball in winning game or not. 



    // Make sure it is the same playground as in smart contract
        // choose any hash function, then check if its correct with the current playground new_playground
        // then the hashed value store it in new_playground.
        // component hashPoseidon0 = Poseidon(16);
        // for(var i = 0; i < 16; i++){
        //     hashPoseidon0.inputs[i] <== playground[i];
        // }
        // hashPoseidon0.out === current_playground_commit;
        // component hashPoseidon1 = Poseidon(16);
        // for(var i = 0; i < 16; i++){
        //     hashPoseidon1.inputs[i] <== new_playground[i];
        // }
        // hashPoseidon1.out ==> new_playground_commit; // The new playground should goes here

    // Make sure players cards are the same as in smart contract
        // choose any hash function, then check if its correct with the current new_cards_commit  
        // component hashPoseidon2 = Poseidon(5);
        // for(var i = 0; i < 5; i++){
        //     hashPoseidon2.inputs[i] <== players_cards[i];
        // }
        // hashPoseidon1.out === players_cards_commit;
        // component hashPoseidon3 = Poseidon(4);
        // for(var i = 0; i < 4; i++){
        //     hashPoseidon3.inputs[i] <== new_players_cards[i];
        // }
        // hashPoseidon3.out ==> new_cards_commit; // The new cards commit should goes here