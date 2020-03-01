# extraction-metadata-changes
Client interface tool that talks with the metadata service to store and apply all
metadata modifications in a single transaction.

# How to use it

Add this line to your Gemfile:

```ruby
gem "extraction_metadata_changes"
```

# Getting started

## Building a modifications object

To build a set of metadata modifications, first we need to build a FactChanges object:

```ruby
> changes = FactChanges.new
```

This object will store the modifications that we want to apply in a single transaction so
we can run different methods to create these modifications. The list of available
modifications is:

 * Create/Delete assets

```ruby
# Using asset *variable* notation:
 > changes.create_assets(["?my_car", "?another_car"])
# Or any valid uuid:
 > changes.create_assets(["00000000-0000-0000-0000"])
 > changes.delete_assets(["00000000-0000-0000-0000"])
```

 * Add/Remove properties

```ruby
 > changes.add(asset.uuid, "color", "Red")
 > changes.remove_where(asset, "size", "Big")
```

 * Add/Remove relations

``` ruby
 > changes.add(asset, "quickerThan", asset2)
 > changes.removeWhere(asset, "quickerThan", asset3)
 ```

 * Create/Delete groups of assets

```ruby
 # With *variable* notation
 > changes.create_asset_groups(["?my_parking_of_cars", "?another"])
 # With uuid
 > changes.create_asset_groups(["00000000-0000-0000-0000"])
 > changes.delete_asset_groups(["00000000-0000-0000-0000"])
```

 * Add/Remove assets to/from groups

```ruby
 > changes.add_assets_to_group("?my_parking_of_cars", ["?my_car"])
 > changes.remove_assets_from_group("?my_parking_of_cars", ["?card_sold"])
```

 * Specify errors that will avoid the transaction to apply

```ruby
 > changes.set_errors(["This set of modifications are wrong."])
```

# Applying the modifications

Once we have completed all changes we want to apply in a single transaction, we can run
the apply method:

```ruby
> changes.apply(transaction_id)
```

All modifications will be joined under a single transaction, so we need to provide a unique
identifier of this set of modifications. One way of doing this is keeping a separate table that will keep track of the transactions creation an using the id of this table as the transaction id for the metadata service. This transaction id will be the reference of the changes we have apply so we can roll it back later if we ever need it.
that we have apply.
