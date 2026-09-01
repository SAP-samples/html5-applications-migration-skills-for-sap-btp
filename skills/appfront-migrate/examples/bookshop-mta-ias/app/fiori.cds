using {CatalogService} from '../srv/cat-service';
annotate CatalogService.Books with @(
  UI: {
    SelectionFields: [ ID, price, currency_code ],
    LineItem: [
      {Value: title},
      {Value: author, Label:'Author'},
      {Value: price},
      {Value: currency.symbol, Label:'Currency'},
    ]
  }
);