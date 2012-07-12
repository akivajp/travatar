
#include <travatar/sparse-map.h>
#include <travatar/dict.h>

namespace travatar {

bool operator==(const SparseMap & lhs, const SparseMap & rhs) {
    if(lhs.size() != rhs.size())
        return false;
    BOOST_FOREACH(const SparsePair & kv, lhs) {
        SparseMap::const_iterator it = rhs.find(kv.first);
        if(it == rhs.end() || abs(it->second- kv.second) > 1e-6) return false;
    }
    return true;
}
bool operator!=(const SparseMap & lhs, const SparseMap & rhs) {
    return !(lhs == rhs);
}

std::ostream & operator<<(std::ostream & out, const SparseMap & rhs) {
    out << "{";
    int count = 0;
    BOOST_FOREACH(const SparsePair & kv, rhs) {
        if(count++ != 0) out << ", ";
        out << "\"" << Dict::WSym(kv.first) << "\": " << kv.second;
    }
    out << "}";
    return out;
}

SparseMap & operator+=(SparseMap & lhs, const SparseMap & rhs) {
    BOOST_FOREACH(const SparsePair & val, rhs)
        if(val.second != 0)
            lhs[val.first] += val.second;
    return lhs;
}

double operator*(const SparseMap & lhs, const SparseMap & rhs) {
    double ret = 0;
    BOOST_FOREACH(const SparsePair & val, lhs) {
        SparseMap::const_iterator it = rhs.find(val.first);
        if(it != rhs.end()) {
            ret += val.second * it->second;
        }
    }
    return ret;
}

}