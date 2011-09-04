# By default, Sequel uses the MyISAM storage engine. Unfortunately, that's slower, more prone to corruption,
# has coarser-grain locking and can't do transactions.
Sequel::MySQL.default_engine = "InnoDB"
