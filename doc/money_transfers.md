
Description des flux de BTC dans l'application
==============================================

1 ) L'utilisateur crédite son compte
------------------------------------

L'utilisateur possède une adresse public générée à partir de notre Wallet Determinitic.
Il envoie sur cette adresse une certaine somme de BTC (disons 0.5 BTC).
Notre Bitcoin Node détecte la transaction sur le réseau (car il surveille les transactions de notre HD Wallet).
Il crédite alors le compte de l'utilisateur de la somme en question.
L'utilisateur peut alors voir sur son compte la somme disponible (0.5 BTC).

2 ) L'utilisateur crée un ordre
-------------------------------

Depuis son compte, l'utilisateur peut créer un ordre.
Il doit pour celà renseigner la somme de BTC à y consacrer, le prix en BTC / MHs / jour, les informations de la pool sur laquelle les miners vont devoir se connecter et éventuellement une limitation de puissance.
Disons qu'il crée un ordre de 0.2 BTC, à 0.005 BTC / MH/s / jour.
La somme de 0.2 BTC est débitée de son compte, et ajoutée comme somme disponible dans le order.
Le compte de l'utilisateur n'affiche donc plus que 0.3 BTC disponible.

3 ) Les shares sont payés
-------------------------

Les miners qui travaillent sur cet ordre créent des shares d'une certaine difficulté, représentative du travail fourni.
Toutes les quelques minutes, ces shares sont payés.
On récupère toutes ceux qui ne sont pas payés, et on calcul ne nombre de MH fourni (à partir de la somme des difficultés).
On calcul ensuite le montant à payer, basé sur le prix.
Ce prix est déduit de la somme disponible pour cet ordre.
Le montant à payer est ensuite divisé entre chaque miner en fonction de leur travail respectif et les frais de gestion de la pool.
Pour chaque miner, on crée un tranfert de la somme à créditer et on attache le tranfer à chaque share pour la traçabilité.
On crée aussi un transfert à l'intention de la pool.
La somme des montants de ces tranferts est égale au montant calaculé plus haut.
La balance de chaque miner est alors visible sur la page lui correspondant.

4 ) Payout
----------

Toutes les quelques heures, les miners sont payés sur l'adresse qu'ils ont fourni.
On récupère tous les tranferts à destination des miners qui n'ont pas été payé, on les groupe par miner ce qui crée un montant à payer par miner.
On crée la transaction bitcoin correspondante, et on l'envoie.
On associe ensuite à chacun des transferts mentionnés la transaction (pour la traçabilité).
Un nouveau transfert est ensuite créé pour déduire cette somme su compte du miner.

La transaction bitcoin utilise comme 'in' toutes les transactions de crédit qui n'ont pas encore été dépensée,
et l'adresse du compte de HashFarm, sur laquelle sont recréditées les sommes non dépensées, et sur laquelle sont versés les fees.

5 ) Annulation d'un ordre
-------------------------

Si un utilisateur décide d'annuler son ordre,
la pool créée pour cet ordre est arrêté,
les shares envoyés pour cet ordre sont payés,
le montant est donc déduit de la somme restante sur cet ordre,
et, si il reste de l'argent, le montant restant est recrédité sur le compte de l'utilisateur via la création d'un transfer.
L'ordre est marqué comme 'complété'.

6 ) L'utilisateur récupère ses fonds
------------------------------------

L'utilisateur peut, à tout moment, demander le retrait de ses fonds.
Son compte est alors débité de la somme restante (via la création d'un transfert),
et une transaction bitcoin est crée sur l'adresse qu'il aura mentionné.

La transaction bitcoin utilise comme 'in' l'adresse du compte de HashFarm et les transactions de crédit non encore dépensées.
