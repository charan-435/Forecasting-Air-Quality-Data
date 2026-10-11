import numpy as np


def haar_modwt(x, J):
    """Circular Haar MODWT. Returns [W_1, ..., W_J] and V_J."""
    V = np.asarray(x, dtype=float)
    W = []
    for j in range(1, J + 1):
        s = 2 ** (j - 1)
        V_lag = np.roll(V, s)          # V_{j-1, t-s}
        W.append((V - V_lag) / 2)      # wavelet (detail) coefficients
        V = (V + V_lag) / 2            # scaling (smooth) coefficients
    return W, V


def haar_inverse_step(W_j, V_j, j):
    """Recover V_{j-1} from W_j and V_j."""
    s = 2 ** (j - 1)
    return (W_j - np.roll(W_j, -s) + V_j + np.roll(V_j, -s)) / 2


def haar_imodwt(W, V_J):
    V = V_J
    for j in range(len(W), 0, -1):
        V = haar_inverse_step(W[j - 1], V, j)
    return V


def haar_mra(x, J):
    """Details D_1..D_J and smooth S_J with x = sum(D) + S."""
    W, V_J = haar_modwt(x, J)
    zeros = [np.zeros_like(w) for w in W]
    D = [haar_imodwt(zeros[:j] + [W[j]] + zeros[j + 1:], np.zeros_like(V_J))
         for j in range(J)]
    S = haar_imodwt(zeros, V_J)
    return D, S


if __name__ == "__main__":
    x = np.array([20, 22, 25, 24, 28, 30, 27, 26], dtype=float)
    W, V3 = haar_modwt(x, 3)
    D, S3 = haar_mra(x, 3)
    print("W1 =", W[0])
    print("V3 =", V3)
    print("perfect reconstruction:", np.allclose(haar_imodwt(W, V3), x))
    print("MRA adds up:", np.allclose(sum(D) + S3, x))
    print("energy preserved:", np.isclose((x ** 2).sum(),
                                          sum((w ** 2).sum() for w in W) + (V3 ** 2).sum()))
