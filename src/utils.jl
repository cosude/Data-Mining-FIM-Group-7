function filter_and_sort(Trans::AbstractVector{T}, FList::AbstractVector{T}) where T
    trans_items = Set(Trans)
    sorted_frequent_items = T[item for item in FList if item in trans_items]
    return sorted_frequent_items
end