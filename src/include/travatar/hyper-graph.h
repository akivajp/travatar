#ifndef TRABATAR_HYPER_GRAPH__
#define TRABATAR_HYPER_GRAPH__

#include <vector>
#include <boost/foreach.hpp>
#include <travatar/dict.h>

namespace travatar {

typedef short NodeId;
class HyperNode;

// A hyperedge in the hypergraph
class HyperEdge {
protected:
    NodeId id_;
    HyperNode* head_;
    std::vector<HyperNode*> tails_;
    double score_;
public:
    HyperEdge(HyperNode* head = NULL) : id_(-1), head_(head), score_(1) { };
    ~HyperEdge() { };

    // Adder
    void AddTail(HyperNode* tail) { tails_.push_back(tail); }

    // Get the probability (score, and must be between 0 and 1
    double GetProb() {
#ifdef TRAVATAR_SAFE
        if(!(score_ >= 0 && score_ <= 1))
            THROW_ERROR("Invalid probability "<<score_);
#endif
        return score_;
    }

    // Getters/Setters
    void SetId(NodeId id) { id_ = id; }
    NodeId GetId() const { return id_; }
    const std::vector<HyperNode*> & GetTails() const { return tails_; }
    std::vector<HyperNode*> & GetTails() { return tails_; }

    // Operators
    bool operator==(const HyperEdge & rhs) const;
    bool operator!=(const HyperEdge & rhs) const {
        return !(*this == rhs);
    }

    // Input/Output
    void Print(std::ostream & out) const;

};
inline std::ostream &operator<<( std::ostream &out, const HyperEdge &L ) {
    L.Print(out);
    return out;
}

// A hypernode in the hypergraph
class HyperNode {
public:
    typedef enum {
        IS_FRONTIER = 'Y',
        NOT_FRONTIER = 'N',
        UNSET_FRONTIER = 'U'
    } FrontierType;
private:
    WordId sym_;
    std::pair<int,int> span_;
    NodeId id_;
    FrontierType frontier_;
    std::vector<HyperEdge*> edges_;
    Sentence target_words_;
public:
    HyperNode(WordId sym = -1,
              std::pair<int,int> span = std::pair<int,int>(-1,-1),
              int id = -1) : 
        sym_(sym), span_(span), id_(id), frontier_(UNSET_FRONTIER) { };
    ~HyperNode() { };

    // Information
    int NumEdges() const { return edges_.size(); }
    bool IsTerminal() const { return edges_.size() == 0; }

    // Adders
    void AddEdge(HyperEdge* edge) { edges_.push_back(edge); }

    // Getters/Setters
    void SetSym(WordId sym) { sym_ = sym; }
    WordId GetSym() const { return sym_; }
    void SetId(NodeId id) { id_ = id; }
    NodeId GetId() const { return id_; }
    const std::pair<int,int> & GetSpan() const { return span_; }
    std::pair<int,int> & GetSpan() { return span_; }
    const std::vector<HyperEdge*> GetEdges() const { return edges_; }
    std::vector<HyperEdge*> GetEdges() { return edges_; }
    const HyperEdge* GetEdge(int i) const { return SafeAccess(edges_, i); }
    HyperEdge* GetEdge(int i) { return SafeAccess(edges_, i); }
    void SetTargetWords(const Sentence & tw) { target_words_ = tw; }
    FrontierType IsFrontier() const { return frontier_; }
    void SetFrontier(FrontierType frontier) { frontier_ = frontier; }

    // Operators
    bool operator==(const HyperNode & rhs) const;
    bool operator!=(const HyperNode & rhs) const {
        return !(*this == rhs);
    }

    // IO Functions
    void Print(std::ostream & out) const;

};
inline std::ostream &operator<<( std::ostream &out, const HyperNode &L ) {
    L.Print(out);
    return out;
}

// The hypergraph
class HyperGraph {
protected:
    int id_;
    std::vector<HyperNode*> nodes_;
    std::vector<HyperEdge*> edges_;
    std::vector<WordId> words_;
public:

    HyperGraph() : id_(-1) { };
    ~HyperGraph() {
        BOOST_FOREACH(HyperNode* node, nodes_)
            delete node;
        BOOST_FOREACH(HyperEdge* edge, edges_)
            delete edge;
    };

    // Check to make sure two hypergraphs are equal
    //  (print an error and return zero if not)
    int CheckEqual(const HyperGraph & rhs) const;

    // Adders. Add the value, and set its ID appropriately
    // HyperGraph will take control of the added value
    void AddNode(HyperNode * node) {
        node->SetId(nodes_.size());
        nodes_.push_back(node);
    }
    void AddEdge(HyperEdge * edge) {
        edge->SetId(edges_.size());
        edges_.push_back(edge);
    }

    // Accessors
    const HyperNode* GetNode(int i) const { return SafeAccess(nodes_,i); }
    HyperNode* GetNode(int i) { return SafeAccess(nodes_,i); }
    const std::vector<HyperNode*> GetNodes() const { return nodes_; }
    std::vector<HyperNode*> GetNodes() { return nodes_; }
    int NumNodes() const { return nodes_.size(); }
    const HyperEdge* GetEdge(int i) const { return SafeAccess(edges_,i); }
    HyperEdge* GetEdge(int i) { return SafeAccess(edges_,i); }
    int NumEdges() const { return edges_.size(); }
    const std::vector<WordId> & GetWords() const { return words_; }
    std::vector<WordId> & GetWords() { return words_; }
    void SetWords(const std::vector<WordId> & words) { words_ = words; }

};

// A fragment of a hypergraph with a corresponding probability
// This should generally be used for extracting rules
class GraphFragment {
public:
    GraphFragment(HyperEdge * edge = NULL) : prob_(1) {
        if(edge != NULL) AddEdge(edge);
    }
    void AddEdge(HyperEdge* edge) {
        edges_.push_back(edge);
        prob_ *= edge->GetProb();
    }
    bool operator==(const GraphFragment & rhs) const {
        if(prob_ != rhs.prob_ || edges_.size() != rhs.edges_.size())
            return false;
        for(int i = 0; i < (int)edges_.size(); i++)
            if(*edges_[i] != *rhs.edges_[i])
                return false;
        return true;
    }
    bool operator!=(const GraphFragment & rhs) const {
        return !(*this == rhs);
    }
    // Input/Output
    void Print(std::ostream & out) const;
private:
    std::vector<HyperEdge*> edges_;
    double prob_;
};
inline std::ostream &operator<<( std::ostream &out, const GraphFragment &L ) {
    L.Print(out);
    return out;
}

}

#endif
