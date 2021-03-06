#ifndef LOOKUP_TABLE_FSM_H__
#define LOOKUP_TABLE_FSM_H__

#include <travatar/graph-transformer.h>
#include <travatar/sentence.h>
#include <travatar/sparse-map.h>
#include <travatar/translation-rule-hiero.h>
#include <marisa/marisa.h>
#include <boost/shared_ptr.hpp>
#include <vector>
#include <map>
#include <set>

namespace travatar {

class HyperNode;
class HyperEdge;
class LookupNodeFSM;
class TranslationRuleHiero;

typedef std::vector<std::pair<int,int> > HieroRuleSpans;
typedef std::map<HieroHeadLabels, HyperNode*> HeadNodePairs;
typedef std::map<std::pair<int,int>, HeadNodePairs> HieroNodeMap;
typedef std::vector<HyperEdge* > EdgeList;
typedef std::pair<int, std::pair<int,int> > TailSpanKey;
typedef std::map<HieroHeadLabels,std::set<HieroHeadLabels> > UnaryMap;
typedef std::map<WordId, LookupNodeFSM*> LookupNodeMap;
typedef std::map<HieroHeadLabels, LookupNodeFSM*> NTLookupNodeMap;
class LookupNodeFSM {
protected:
    LookupNodeMap lookup_map_;
    NTLookupNodeMap nt_lookup_map_;
    std::vector<TranslationRuleHiero*> rules_;
    std::set<WordId> labels_;
public:
    LookupNodeFSM() { }
    virtual ~LookupNodeFSM();
    
    void AddEntry(const WordId & key, LookupNodeFSM* chile_node);
    void AddNTEntry(const HieroHeadLabels& key, LookupNodeFSM* child_node);
    LookupNodeFSM* FindChildNode(const WordId key) const;
    LookupNodeFSM* FindNTChildNode (const HieroHeadLabels& key) const;
    LookupNodeMap & GetNodeMap() { return lookup_map_; }
    const LookupNodeMap & GetNodeMap() const { return lookup_map_; }
    const NTLookupNodeMap & GetNTNodeMap() const { return nt_lookup_map_; }
    void AddRule(TranslationRuleHiero* rule);
    const std::vector<TranslationRuleHiero*> & GetTranslationRules() const { return rules_; }

    virtual void Print(std::ostream &out, WordId label, int indent, char prefix) const; 
}; 

// inline std::ostream &operator<<( std::ostream &out, const LookupNodeFSM &L ) {
//     L.Print(out,Dict::WID("ROOT"),0,'-');
//     return out;
// }

class RuleFSM {
protected:
    typedef std::vector<TranslationRuleHiero*> RuleVec;
    typedef std::vector<RuleVec> RuleSet; 

    // The trie indexing the rules, and the rules
    marisa::Trie trie_;
    RuleSet rules_;

    // Other statistics
    UnaryMap unaries_;
    int span_length_;
    bool save_src_str_;
public:

    friend class LookupTableFSM;

    RuleFSM() : span_length_(20), save_src_str_(false) { }

    virtual ~RuleFSM();
    
    static RuleFSM * ReadFromRuleTable(std::istream & in);

    static TranslationRuleHiero * BuildRule(travatar::TranslationRuleHiero * rule, std::vector<std::string> & source, 
            std::vector<std::string> & target, SparseMap& features);

    // ACCESSOR
    int GetSpanLimit() const { return span_length_; } 
    const RuleSet & GetRules() const { return rules_; }
    const marisa::Trie & GetTrie() const { return trie_; }
    RuleSet & GetRules() { return rules_; }
    marisa::Trie & GetTrie() { return trie_; }
 
    // MUTATOR
    void SetSpanLimit(const int length) { span_length_ = length; }
    void SetSaveSrcStr(const bool save_src_str) { save_src_str_ = save_src_str; }

protected:
    void BuildHyperGraphComponent(HieroNodeMap & node_map, EdgeList & edge_set,
        const Sentence & input, const std::string & state, int position, HieroRuleSpans & spans) const;

    static std::string CreateKey(const CfgData & src_data,
                                 const std::vector<CfgData> & trg_data);
private:
    // void AddRule(int position, LookupNodeFSM* target_node, TranslationRuleHiero* rule);
};

// inline std::ostream &operator<<( std::ostream &out, const RuleFSM &L ) {
//     L.Print(out);
//     return out;
// }

class LookupTableFSM : public GraphTransformer {
protected:
    std::vector<RuleFSM*> rule_fsms_;
    bool delete_unknown_;
    int trg_factors_;
    HieroHeadLabels root_symbol_;
    HieroHeadLabels unk_symbol_;
    bool save_src_str_;
public:
    LookupTableFSM();
    ~LookupTableFSM();

    void AddRuleFSM(RuleFSM* fsm) {
        rule_fsms_.push_back(fsm);
    }

    // Transform a graph of words into a hiero graph
    virtual HyperGraph * TransformGraph(const HyperGraph & graph) const;

    const HieroHeadLabels & GetRootSymbol() const { return root_symbol_; } 
    const HieroHeadLabels & GetUnkSymbol() const { return unk_symbol_; } 
    bool GetDeleteUnknown() const { return delete_unknown_; } 

    void SetDeleteUnknown(bool delete_unk) { delete_unknown_ = delete_unk; }
    void SetRootSymbol(WordId symbol) { root_symbol_ = HieroHeadLabels(std::vector<WordId>(trg_factors_+1,symbol)); }
    void SetSpanLimits(const std::vector<int>& limits);
    void SetTrgFactors(const int trg_factors) { trg_factors_ = trg_factors; } 
    void SetSaveSrcStr(const bool save_src_str);

    static TranslationRuleHiero* GetUnknownRule(WordId unknown_word, const HieroHeadLabels& head_labels);

    static LookupTableFSM * ReadFromFiles(const std::vector<std::string> & filenames);

    static HyperEdge* TransformRuleIntoEdge(HieroNodeMap& map, const int head_first, 
            const int head_second, const std::vector<TailSpanKey > & tail_spans, TranslationRuleHiero* rule, bool save_src_str=false);

    static HyperEdge* TransformRuleIntoEdge(TranslationRuleHiero* rule, const HieroRuleSpans & rule_span, HieroNodeMap & node_map, bool save_src_str=false);

    static HyperNode* FindNode(HieroNodeMap& map, const int span_begin, const int span_end, const HieroHeadLabels& head_label);
    
};
}

#endif
