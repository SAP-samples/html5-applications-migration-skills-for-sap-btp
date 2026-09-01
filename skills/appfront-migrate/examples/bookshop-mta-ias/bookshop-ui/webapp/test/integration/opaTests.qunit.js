sap.ui.require(
    [
        'sap/fe/test/JourneyRunner',
        'bookshopapp/test/integration/FirstJourney',
		'bookshopapp/test/integration/pages/ListOfBooksList',
		'bookshopapp/test/integration/pages/ListOfBooksObjectPage',
		'bookshopapp/test/integration/pages/Books_textsObjectPage'
    ],
    function(JourneyRunner, opaJourney, ListOfBooksList, ListOfBooksObjectPage, Books_textsObjectPage) {
        'use strict';
        var JourneyRunner = new JourneyRunner({
            // start index.html in web folder
            launchUrl: sap.ui.require.toUrl('bookshopapp') + '/index.html'
        });

       
        JourneyRunner.run(
            {
                pages: { 
					onTheListOfBooksList: ListOfBooksList,
					onTheListOfBooksObjectPage: ListOfBooksObjectPage,
					onTheBooks_textsObjectPage: Books_textsObjectPage
                }
            },
            opaJourney.run
        );
    }
);