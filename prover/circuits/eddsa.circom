include "../node_modules/circomlib/circuits/compconstant.circom";
include "../node_modules/circomlib/circuits/comparators.circom";
include "../node_modules/circomlib/circuits/pointbits.circom";
include "../node_modules/circomlib/circuits/mimcsponge.circom";
include "../node_modules/circomlib/circuits/bitify.circom";
include "../node_modules/circomlib/circuits/escalarmulany.circom";
include "../node_modules/circomlib/circuits/escalarmulfix.circom";

include "./hasher.circom";


template EdDSAMiMCSpongeVerifierPatched() {
  // This is a patched version of EdDSAMiMCSpongeVerifier that
  // has a "valid" field to determine if the signature is valid
  signal input Ax;
  signal input Ay;

  signal input S;
  signal input R8x;
  signal input R8y;

  signal input M;

  signal output valid;

  var i;

  // Ensure S<Subgroup Order
  component snum2bits = Num2Bits(253);
  snum2bits.in <== S;

  component compConstant = CompConstant(2736030358979909402780800718157159386076813972158567259200215660948447373040);

  for (i=0; i<253; i++) {
    snum2bits.out[i] ==> compConstant.in[i];
  }
  compConstant.in[253] <== 0;
  compConstant.out === 0;

  // Calculate the h = H(R,A, msg)
  component hash = MiMCSponge(5, 220, 1);
  hash.ins[0] <== R8x;
  hash.ins[1] <== R8y;
  hash.ins[2] <== Ax;
  hash.ins[3] <== Ay;
  hash.ins[4] <== M;
  hash.k <== 0;

  component h2bits = Num2Bits_strict();
  h2bits.in <== hash.outs[0];

  // Calculate second part of the right side:  right2 = h*8*A

  // Multiply by 8 by adding it 3 times.  This also ensure that the result is in
  // the subgroup.
  component dbl1 = BabyDbl();
  dbl1.x <== Ax;
  dbl1.y <== Ay;
  component dbl2 = BabyDbl();
  dbl2.x <== dbl1.xout;
  dbl2.y <== dbl1.yout;
  component dbl3 = BabyDbl();
  dbl3.x <== dbl2.xout;
  dbl3.y <== dbl2.yout;

  // We check that A is not zero.
  component isZero = IsZero();
  isZero.in <== dbl3.x;
  isZero.out === 0;

  component mulAny = EscalarMulAny(254);
  for (i=0; i<254; i++) {
    mulAny.e[i] <== h2bits.out[i];
  }
  mulAny.p[0] <== dbl3.xout;
  mulAny.p[1] <== dbl3.yout;


  // Compute the right side: right =  R8 + right2
  component addRight = BabyAdd();
  addRight.x1 <== R8x;
  addRight.y1 <== R8y;
  addRight.x2 <== mulAny.out[0];
  addRight.y2 <== mulAny.out[1];

  // Calculate left side of equation left = S*B8
  var BASE8 = [
    5299619240641551281634865583518297030282874472190772894086521144482721001553,
    16950150798460657717958625567821834550301663161624707787222815936182638968203
  ];
  component mulFix = EscalarMulFix(253, BASE8);
  for (i=0; i<253; i++) {
    mulFix.e[i] <== snum2bits.out[i];
  }

  // Valid should equal to 0 if its valid
  component rightValid = IsEqual();
  rightValid.in[0] <== mulFix.out[0];
  rightValid.in[1] <== addRight.xout;

  component leftValid = IsEqual();
  leftValid.in[0] <== mulFix.out[1];
  leftValid.in[1] <== addRight.yout;

  component isValid = IsEqual();
  isValid.in[0] <== rightValid.out + leftValid.out;
  isValid.in[1] <== 2

  valid <== isValid.out;
}


template VerifyEdDSASignature(k) {
  signal input fromX;
  signal input fromY;
  signal input R8x;
  signal input R8y;
  signal input S;
  signal private input preimage[k];

  signal output valid;
  
  component M = Hasher(k);
  M.key <== 0;
  for (var i = 0; i < k; i++){
    M.in[i] <== preimage[i];
  }
  
  component verifier = EdDSAMiMCSpongeVerifierPatched();

  verifier.Ax <== fromX;
  verifier.Ay <== fromY;
  verifier.S <== S;
  verifier.R8x <== R8x;
  verifier.R8y <== R8y;
  verifier.M <== M.hash;

  valid <== verifier.valid;
}