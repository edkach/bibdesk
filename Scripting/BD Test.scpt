FasdUAS 1.101.10   ��   ��    k             l    ��  O      	  k    
 
     l   �� ��    Y S Get first document and talk to it. Certain things won't work for the others anyway         r        n    
    4    
�� 
�� 
cobj  m    	����   2   ��
�� 
docu  o      ���� 0 d        l   ������  ��        l   �    O    �    k    �       l   ��  ��     - ' we can use whose right out of the box!      ! " ! r    " # $ # n      % & % 4     �� '
�� 
cobj ' m    ����  & l    (�� ( 6    ) * ) 2   ��
�� 
bibi * E     + , + 1    ��
�� 
ckey , m     - -  DG   ��   $ o      ���� 0 p   "  . / . l  # #������  ��   /  0 1 0 l  # #�� 2��   2 * $ THINGS WE CAN DO WITH A PUBLICATION    1  3 4 3 l  # S 5 6 5 O   # S 7 8 7 k   ' R 9 9  : ; : l  ' '�� <��   < 1 + all properties give quite a lengthy output    ;  = > = l  ' '�� ?��   ?   get properties    >  @ A @ l  ' '������  ��   A  B C B l  ' '�� D��   D � � we can access all fields, but this has to be done in a two-step process for some mysterious AppleScript reason. The keys have to be surrounded by pipes.    C  E F E r   ' , G H G 1   ' *��
�� 
flds H o      ���� 0 f   F  I J I e   - 1 K K n   - 1 L M L o   . 0���� 0 Journal   M o   - .���� 0 f   J  N O N l  2 2������  ��   O  P Q P l  2 2�� R��   R I C plurals as well as accessing a whole array of things  work as well    Q  S T S n   2 8 U V U 1   5 7��
�� 
aunm V 2  2 5��
�� 
auth T  W X W l  9 9������  ��   X  Y Z Y l  9 9�� [��   [ - ' as does access to the local file's URL    Z  \ ] \ l  9 9�� ^��   ^ | v This is nice but the whole differences between Unix and traditional AppleScript style paths seem to make it worthless    ]  _ ` _ r   9 > a b a 1   9 <��
�� 
lURL b o      ���� 0 lf   `  c d c l  ? ?������  ��   d  e f e l  ? ?�� g��   g #  we can easily set properties    f  h i h r   ? H j k j m   ? B l l  http://localhost/lala/    k 1   B G��
�� 
rURL i  m n m l  I I������  ��   n  o p o l  I I�� q��   q + % and get the underlying BibTeX record    p  r�� r r   I R s t s 1   I N��
�� 
BTeX t o      ���� 0 bibtexrecord BibTeXRecord��   8 o   # $���� 0 p   6   p    4  u v u l  T T������  ��   v  w x w l  T T�� y��   y + % GENERATING AND DELETING PUBLICATIONS    x  z { z l  T T�� |��   |   let's make a new record    {  } ~ } r   T j  �  I  T f���� �
�� .corecrel****      � null��   � �� � �
�� 
kocl � m   X Y��
�� 
bibi � �� ���
�� 
insh � l  \ ` ��� � n   \ ` � � �  ;   _ ` � 2  \ _��
�� 
bibi��  ��   � o      ���� 0 n   ~  � � � l  k k�� ���   � ? 9 this is initially empty, so fill it with a BibTeX string    �  � � � r   k v � � � o   k n���� 0 bibtexrecord BibTeXRecord � n       � � � 1   q u��
�� 
BTeX � o   n q���� 0 n   �  � � � l  w w�� ���   �    get rid of the new record    �  � � � I  w ~�� ���
�� .coredelonull��� ��� obj  � o   w z���� 0 n  ��   �  � � � l   ������  ��   �  � � � l   �� ���   � !  MANIPULATING THE SELECTION    �  � � � l   �� ���   � L F Play with the selection and put styled bibliography on the clipboard.    �  � � � r    � � � � 6   � � � � 2   ���
�� 
bibi � E   � � � � � 1   � ���
�� 
ckey � m   � � � �  DG    � o      ���� 0 ar   �  � � � r   � � � � � o   � ����� 0 ar   � 1   � ���
�� 
sele �  � � � I  � �������
�� .MMcCsbtcnull��� ��� obj ��  ��   �  � � � l  � �������  ��   �  � � � l  � ��� ���   �   FILTERING AND SEARCHING    �  � � � l  � ��� ���   � y s We can get and set the filter field of each document and get the list of publications that is currently displayed.    �  � � � l  � ��� ���   ���In addition there is the search command which returns the results of a search. That search matches only the cite key, the authors' surnames and the publication's title. Warning: its results may be different from what's seen when using the filter field for the same term. It is mainly intended for autocompletion use and using 'whose' statements to search for publications should be more powerful, but slower.    �  � � � Z   � � � ��� � � =  � � � � � 1   � ���
�� 
filt � m   � � � �       � r   � � � � � m   � � � �  gerbe    � 1   � ���
�� 
filt��   � r   � � � � � m   � � � �       � 1   � ���
�� 
filt �  � � � e   � � � � 1   � ���
�� 
disp �  � � � e   � � � � I  � ����� �
�� .MMcCsrchlist    ��� obj ��   � �� ���
�� 
for  � m   � � � �  gerbe   ��   �  � � � l  � ��� ���   � r l When writing an AppleScript for completion support in other applications use the 'for completion' parameter    �  � � � e   � � � � I  � ����� �
�� .MMcCsrchlist    ��� obj ��   � �� � �
�� 
for  � m   � � � �  gerbe    � �� ���
�� 
cmpl � m   � ���
�� savoyes ��   �  ��� � l  � �������  ��  ��    o    ���� 0 d      d      � � � l  � �������  ��   �  � � � l  � ��� ���   � � � The search command works also at application level. It will either search every document in that case, or the one it is addressed to.    �  � � � I  � ����� �
�� .MMcCsrchlist    ��� obj ��   � �� ���
�� 
for  � m   � � � �  gerbe   ��   �  � � � I  ��� � �
�� .MMcCsrchlist    ��� obj  � 4  � ��� �
�� 
docu � m   � �����  � �� ���
�� 
for  � m   � �  gerbe   ��   �  � � � l 		�� ���   �  y AppleScript lets us easily set the filter field in all open documents. This is used in the LaunchBar integration script.    �  ��� � O 	 � � � r   � � � m   � � 
 chen    � 1  ��
�� 
filt � 2  	��
�� 
docu��   	 m      � ��null     ߀�� KvBibdesk.app��� �0�L��� 7����   @ �@   )       �(�K� ��� �BDSK   alis    b  Kalle                      |%�JH+   KvBibdesk.app                                                     {Խ"A        ����  	                builds    |%�:      �!�!     Kv d� %�  "E  ,Kalle:Users:ssp:Developer:builds:Bibdesk.app    B i b d e s k . a p p    K a l l e  &Users/ssp/Developer/builds/Bibdesk.app  /    
��  ��     � � � l     ������  ��   �  ��� � l     �����  �  ��       
�~ � � � � � � �~   � �}�|�{�z�y�x�w�v
�} .aevtoappnull  �   � ****�| 0 d  �{ 0 p  �z 0 f  �y 0 lf  �x 0 bibtexrecord BibTeXRecord�w 0 n  �v 0 ar   � �u�t�s�r
�u .aevtoappnull  �   � **** k      �q�q  �t  �s     , ��p�o�n�m�l -�k�j�i�h�g�f�e�d l�c�b�a�`�_�^�]�\�[ ��Z�Y�X�W � � ��V�U ��T ��S�R � � �
�p 
docu
�o 
cobj�n 0 d  
�m 
bibi  
�l 
ckey�k 0 p  
�j 
flds�i 0 f  �h 0 Journal  
�g 
auth
�f 
aunm
�e 
lURL�d 0 lf  
�c 
rURL
�b 
BTeX�a 0 bibtexrecord BibTeXRecord
�` 
kocl
�_ 
insh�^ 
�] .corecrel****      � null�\ 0 n  
�[ .coredelonull��� ��� obj �Z 0 ar  
�Y 
sele
�X .MMcCsbtcnull��� ��� obj 
�W 
filt
�V 
disp
�U 
for 
�T .MMcCsrchlist    ��� obj 
�S 
cmpl
�R savoyes �r�*�-�k/E�O� �*�-�[�,\Z�@1�k/E�O� -*�,E�O��,EO*�-�,EO*�,E�Oa *a ,FO*a ,E` UO*a �a *�-6a  E` O_ _ a ,FO_ j O*�-�[�,\Za @1E` O_ *a ,FO*j O*a ,a   a  *a ,FY a !*a ,FO*a ",EO*a #a $l %O*a #a &a 'a (a  %OPUO*a #a )l %O*�k/a #a *l %O*�- a +*a ,FUU �   ��Q	
�Q 
docu	 �

  B D   t e s t . b i b �  �P�O  ��N
�N 
docu �  B D   t e s t . b i b
�P 
bibi�O  � �M�M 0 Url   � , h t t p : / / l o c a l h o s t / l a l a / �L�L 0 Journal   � & C o m m u n .   M a t h .   P h y s . �K�K 	0 Title   � f { H i g g s   f i e l d s ,   b u n d l e   g e r b e s   a n d   s t r i n g   s t r u c t u r e s } �J�J 0 Year   �  2 0 0 3 �I�I 	0 Pages   �  5 4 1 - - 5 5 5 �H�H 0 Rss-Description   �     �G!"�G 0 Abstract  ! �##  " �F$%�F 0 Keywords  $ �&&  % �E'(�E 	0 Month  ' �))  ( �D*+�D 
0 Number  * �,,  + �C-.�C 0 	Local-Url  - �// X / U s e r s / s s p / Q u e l l e n / M a t h e / m a t h . D G - 0 1 0 6 1 7 9 . p d f. �B01�B 
0 Eprint  0 �22 * a r X i v : m a t h . D G / 0 1 0 6 1 7 91 �A34�A 
0 Volume  3 �55  2 4 34 �@67�@ 
0 Annote  6 �88  7 �?9�>�? 
0 Author  9 �:: : M .   K .   M u r r a y   a n d   D .   S t e v e n s o n�>   � �;; X / U s e r s / s s p / Q u e l l e n / M a t h e / m a t h . D G - 0 1 0 6 1 7 9 . p d f  �<<� @ a r t i c l e { m a t h . D G / 0 1 0 6 1 7 9 , 
 	 A u t h o r   =   { M .   K .   M u r r a y   a n d   D .   S t e v e n s o n } , 
 	 E p r i n t   =   { a r X i v : m a t h . D G / 0 1 0 6 1 7 9 } , 
 	 J o u r n a l   =   { C o m m u n .   M a t h .   P h y s . } , 
 	 L o c a l - U r l   =   { / U s e r s / s s p / Q u e l l e n / M a t h e / m a t h . D G - 0 1 0 6 1 7 9 . p d f } , 
 	 P a g e s   =   { 5 4 1 - - 5 5 5 } , 
 	 T i t l e   =   { { H i g g s   f i e l d s ,   b u n d l e   g e r b e s   a n d   s t r i n g   s t r u c t u r e s } } , 
 	 U r l   =   { h t t p : / / l o c a l h o s t / l a l a / } , 
 	 V o l u m e   =   { 2 4 3 } , 
 	 Y e a r   =   { 2 0 0 3 } } == >�=�<>  ��;?
�; 
docu? �@@  B D   t e s t . b i b
�= 
bibi�<  �:A�: A  BCB DD E�9�8E  ��7F
�7 
docuF �GG  B D   t e s t . b i b
�9 
bibi�8 C HH I�6�5I  ��4J
�4 
docuJ �KK  B D   t e s t . b i b
�6 
bibi�5  ascr  ��ޭ